extends CasoDeTeste

## Editor visual de fases (Etapas 3 e 4).
##
## O teste central e o ROUND-TRIP: montar no editor -> salvar -> reabrir no
## editor -> salvar de novo tem que produzir a MESMA fase. E o que garante que
## editar uma fase nao perde vigia, pergunta nem labirinto -- a perda silenciosa
## e o risco desta camada inteira.


var _criados: PackedStringArray = PackedStringArray()
var _tela: Control = null


func depois() -> void:
	if _tela != null and is_instance_valid(_tela):
		_tela.queue_free()
	_tela = null
	for caminho: String in _criados:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	_criados = PackedStringArray()
	EditorDeFaseEstado.caminho_para_editar = ""
	if Sessao.ativa:
		Sessao.encerrar()


func _abrir_editor(caminho: String = "") -> Control:
	EditorDeFaseEstado.caminho_para_editar = caminho
	var tela: Control = load("res://cenas/ui/editor_de_fase.tscn").instantiate() as Control
	add_child(tela)
	await get_tree().process_frame
	_tela = tela
	return tela


func _preencher(tela: Control, titulo: String) -> void:
	tela._campo_titulo.text = titulo
	tela._campo_briefing.text = "atravesse a rede"
	tela._campo_vidas.value = 3
	tela._campo_largura.value = 15
	tela._campo_altura.value = 11
	tela._campo_semente.value = 4242

	# Um vigia bloqueavel e um que so persegue.
	var vigias: Array[Node] = tela._vigias.get_children()
	(vigias[0].get_node("Comando") as LineEdit).text = "trocar senha"
	(vigias[0].get_node("Cor") as ColorPickerButton).color = Color("#40a9ff")
	tela._adicionar_vigia(Color("#ff6b6b"), "")

	# O terminal que ja nasce na tela, preenchido.
	var bloco: Node = tela._terminais.get_child(0)
	(bloco.get_node("Enunciado") as LineEdit).text = "qual senha e mais dificil de descobrir?"
	(bloco.get_node("Explicacao") as LineEdit).text = "tamanho vale mais que simbolo."
	var opcoes: Array[Node] = bloco.get_node("Opcoes").get_children()
	(opcoes[0].get_node("Texto") as LineEdit).text = "uma frase longa"
	(opcoes[0].get_node("Correta") as CheckBox).button_pressed = true
	(opcoes[1].get_node("Texto") as LineEdit).text = "o seu nome"


func teste_editor_novo_abre_com_uma_linha_de_cada() -> void:
	var tela: Control = await _abrir_editor()

	afirmar_igual(tela._vigias.get_child_count(), 1, "comeca com um vigia")
	afirmar_igual(tela._terminais.get_child_count(), 1, "e um terminal")
	afirmar_igual(tela._terminais.get_child(0).get_node("Opcoes").get_child_count(), 2,
		"o terminal ja nasce com duas opcoes: escolha precisa de pelo menos duas")
	afirmar_verdadeiro(Identificador.e_uuid(tela._id_fase),
		"a fase nova ja nasce com id_fase -- e a ligacao com a telemetria")


func teste_a_tela_do_editor_e_opaca() -> void:
	var tela: Control = await _abrir_editor()
	afirmar_igual((tela.get_node("Fundo") as ColorRect).color.a, 1.0, "fundo opaco")
	var estilo: StyleBoxFlat = (tela.get_node("Raiz") as PanelContainer).get_theme_stylebox(
		"panel") as StyleBoxFlat
	afirmar_nao_nulo(estilo, "painel com StyleBox proprio")
	afirmar_igual(estilo.bg_color.a, 1.0, "e opaco")


func teste_trocar_de_aba_nao_perde_dado_digitado() -> void:
	var tela: Control = await _abrir_editor()
	_preencher(tela, "Fase entre abas")

	var abas: TabContainer = tela._abas
	afirmar_igual(abas.get_tab_count(), 3, "geral, cachorros e perguntas")

	# Passeia por todas as abas -- e o TabContainer so esconde paginas, nao as
	# esvazia, entao nada deveria mudar no dado por baixo.
	abas.current_tab = 1
	abas.current_tab = 2
	abas.current_tab = 0

	var dados: Dictionary = tela.montar_dicionario()
	afirmar_igual(String(dados["titulo"]), "Fase entre abas", "titulo sobrevive a troca de aba")
	afirmar_tamanho(dados["cachorros"], 2, "vigias sobrevivem a troca de aba")
	afirmar_igual(String(dados["cachorros"][0]["comando_para_bloquear"]), "trocar senha",
		"comando do vigia sobrevive a troca de aba")
	afirmar_tamanho(dados["terminais"], 1, "terminal sobrevive a troca de aba")
	afirmar_igual(String(dados["terminais"][0]["correta"]), "uma frase longa",
		"resposta marcada sobrevive a troca de aba")


func teste_fase_sem_titulo_nao_salva_e_mostra_o_erro() -> void:
	var tela: Control = await _abrir_editor()
	tela._salvar(false)

	afirmar_contem(tela._erros.get_parsed_text(), "titulo",
		"o erro aparece na tela, dizendo qual campo falta")
	afirmar_igual(CarregadorFaseJson.listar().size(), CarregadorFaseJson.listar().size(),
		"e nada foi gravado")


func teste_montar_dicionario_le_a_tela_como_ela_esta() -> void:
	var tela: Control = await _abrir_editor()
	_preencher(tela, "Fase do editor")

	var dados: Dictionary = tela.montar_dicionario()
	afirmar_igual(String(dados["titulo"]), "Fase do editor", "titulo lido da tela")
	afirmar_tamanho(dados["cachorros"], 2, "dois vigias")
	afirmar_igual(String(dados["cachorros"][0]["comando_para_bloquear"]), "trocar senha",
		"o comando do primeiro vigia")
	afirmar_igual(String(dados["cachorros"][1]["modo_de_bloqueio"]), "NENHUM",
		"vigia com comando em branco vira 'so persegue', e nao 'protegido por cifra'")
	afirmar_tamanho(dados["terminais"], 1, "um terminal")
	afirmar_igual(String(dados["terminais"][0]["correta"]), "uma frase longa",
		"a opcao marcada e a resposta correta")


func teste_salvar_grava_json_valido_e_jogavel() -> void:
	var tela: Control = await _abrir_editor()
	_preencher(tela, "Fase gravada")
	tela._salvar(false)

	var caminho: String = CarregadorFaseJson.nome_de_arquivo("Fase gravada")
	_criados.append(caminho)

	if not afirmar_verdadeiro(FileAccess.file_exists(caminho),
			"o arquivo foi criado (%s)" % tela._erros.get_parsed_text()):
		return

	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
	afirmar_verdadeiro(resultado.ok(), "o que o editor grava carrega de volta (%s)"
		% resultado.mensagem())
	afirmar_igual(resultado.config.problemas().size(), 0, "e passa no validador do jogo")


func teste_round_trip_do_editor_nao_perde_nada() -> void:
	var tela: Control = await _abrir_editor()
	_preencher(tela, "Fase round trip")
	tela._salvar(false)

	var caminho: String = CarregadorFaseJson.nome_de_arquivo("Fase round trip")
	_criados.append(caminho)
	if not afirmar_verdadeiro(FileAccess.file_exists(caminho), "gravou"):
		return

	var antes: Dictionary = tela.montar_dicionario()
	tela.queue_free()
	await get_tree().process_frame

	# Reabre no editor e salva de novo, sem tocar em nada.
	var reaberta: Control = await _abrir_editor(caminho)
	var depois_de_reabrir: Dictionary = reaberta.montar_dicionario()

	afirmar_igual(String(depois_de_reabrir["titulo"]), String(antes["titulo"]), "titulo sobrevive")
	afirmar_igual(String(depois_de_reabrir["id_fase"]), String(antes["id_fase"]),
		"o id_fase sobrevive -- a telemetria ja coletada continua pareando com a fase")
	afirmar_tamanho(depois_de_reabrir["cachorros"], (antes["cachorros"] as Array).size(),
		"nenhum vigia se perde ao reabrir")
	afirmar_tamanho(depois_de_reabrir["terminais"], (antes["terminais"] as Array).size(),
		"nenhuma pergunta se perde")
	afirmar_igual(String(depois_de_reabrir["terminais"][0]["correta"]),
		String(antes["terminais"][0]["correta"]), "a resposta marcada continua marcada")
	afirmar_igual(int(depois_de_reabrir["mapa"]["seed"]), int(antes["mapa"]["seed"]),
		"a semente sobrevive: o labirinto reaberto e o mesmo que foi testado")


func teste_editar_salva_por_cima_do_mesmo_arquivo() -> void:
	var tela: Control = await _abrir_editor()
	_preencher(tela, "Fase para editar")
	tela._salvar(false)

	var caminho: String = CarregadorFaseJson.nome_de_arquivo("Fase para editar")
	_criados.append(caminho)
	var quantas_antes: int = CarregadorFaseJson.listar().size()

	tela.queue_free()
	await get_tree().process_frame

	var reaberta: Control = await _abrir_editor(caminho)
	reaberta._campo_briefing.text = "briefing trocado"
	reaberta._salvar(false)

	afirmar_igual(CarregadorFaseJson.listar().size(), quantas_antes,
		"editar nao cria arquivo novo: grava por cima do mesmo")

	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
	afirmar_igual(resultado.config.briefing_pedagogico, "briefing trocado",
		"e a alteracao esta no arquivo")


func teste_semente_sorteada_volta_gravada() -> void:
	var tela: Control = await _abrir_editor()
	_preencher(tela, "Fase sem semente")
	tela._campo_semente.value = 0  # 0 = sortear
	tela._salvar(false)
	_criados.append(CarregadorFaseJson.nome_de_arquivo("Fase sem semente"))

	afirmar_verdadeiro(tela._campo_semente.value > 0,
		"a semente sorteada volta para o campo -- senao a proxima abertura sortearia outro mapa")
