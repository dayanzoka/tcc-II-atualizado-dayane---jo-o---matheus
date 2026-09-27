extends CasoDeTeste

## Menu e tela de selecao de fases (Etapa 2).
##
## O que os testes travam: a tela abre, lista o que existe em user://fases,
## mostra o erro em vez de esconder a fase quebrada, e nenhum painel novo volta
## a ser transparente -- o bug historico das telas deste projeto.


var _criados: PackedStringArray = PackedStringArray()


func depois() -> void:
	for caminho: String in _criados:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	_criados = PackedStringArray()
	if Sessao.ativa:
		Sessao.encerrar()


func _gravar(nome: String, conteudo: String) -> String:
	CarregadorFaseJson.garantir_pasta()
	var caminho: String = "%s/%s" % [CarregadorFaseJson.pasta_das_fases, nome]
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string(conteudo)
	arquivo.close()
	_criados.append(caminho)
	return caminho


func _json_minimo(titulo: String) -> String:
	return JSON.stringify({
		"titulo": titulo,
		"briefing": "teste",
		"vidas": 3,
		"mapa": {"largura": 15, "altura": 11, "seed": 99},
		"cachorros": [{"cor": "#40a9ff", "comando_para_bloquear": "trocar senha"}],
		"terminais": [{"enunciado": "p?", "opcoes": ["a", "b"], "correta": "a"}],
	})


func teste_menu_tem_as_portas_de_autoria() -> void:
	var menu: Control = load("res://cenas/ui/menu_principal.tscn").instantiate() as Control

	for caminho: String in ["Cartao/Coluna/Botoes/EscolherFase", "Cartao/Coluna/Botoes/CriarFase",
			"Cartao/Coluna/Botoes/SubirFase", "Cartao/Coluna/Botoes/Telemetria", "Cartao/Coluna/Botoes/Sair"]:
		afirmar_nao_nulo(menu.get_node_or_null(caminho), "o menu tem o botao %s" % caminho)

	afirmar_nulo(menu.get_node_or_null("Cartao/Coluna/Botoes/Tutorial"),
		"o tutorial de cores continua fora -- decisao anterior, nao regressao")
	# O jogo nao tem fase propria (ADR 0012): "escolher fase" e o unico
	# caminho para jogar, entao nao ha mais botao "jogar" separado no menu.
	afirmar_nulo(menu.get_node_or_null("Cartao/Coluna/Botoes/Jogar"),
		"nao ha mais atalho para uma fase fixa")
	menu.free()


func teste_a_tela_lista_as_fases_da_pasta() -> void:
	_gravar("zz-teste-alfa.json", _json_minimo("Alfa de teste"))
	_gravar("zz-teste-beta.json", _json_minimo("Beta de teste"))

	var tela: Control = load("res://cenas/ui/selecao_de_fases.tscn").instantiate() as Control
	add_child(tela)
	await get_tree().process_frame

	var lista: ItemList = tela.get_node("Raiz/Margem/Coluna/Corpo/Lista") as ItemList
	var titulos := PackedStringArray()
	for i: int in lista.item_count:
		titulos.append(lista.get_item_text(i))

	afirmar_verdadeiro(titulos.has("Alfa de teste"), "a fase alfa aparece pelo TITULO, nao pelo arquivo")
	afirmar_verdadeiro(titulos.has("Beta de teste"), "a fase beta tambem")

	tela.queue_free()
	await get_tree().process_frame


func teste_fase_quebrada_aparece_marcada_em_vez_de_sumir() -> void:
	_gravar("zz-teste-quebrada.json", "{ isso nao e json valido")

	var tela: Control = load("res://cenas/ui/selecao_de_fases.tscn").instantiate() as Control
	add_child(tela)
	await get_tree().process_frame

	var lista: ItemList = tela.get_node("Raiz/Margem/Coluna/Corpo/Lista") as ItemList
	var achou: bool = false
	for i: int in lista.item_count:
		if lista.get_item_text(i).contains("zz-teste-quebrada.json"):
			achou = true
			# Selecionar a quebrada tem que desabilitar "jogar" e manter
			# "excluir": e assim que o professor se livra do arquivo ruim.
			tela._ao_selecionar(i)
			afirmar_verdadeiro(tela.get_node("Raiz/Margem/Coluna/Acoes/Jogar").disabled,
				"nao da para jogar uma fase quebrada")
			afirmar_falso(tela.get_node("Raiz/Margem/Coluna/Acoes/Excluir").disabled,
				"mas da para exclui-la")
			break

	afirmar_verdadeiro(achou, "a fase quebrada continua na lista, marcada com o erro")

	tela.queue_free()
	await get_tree().process_frame


func teste_a_tela_e_opaca() -> void:
	var tela: Control = load("res://cenas/ui/selecao_de_fases.tscn").instantiate() as Control
	add_child(tela)
	await get_tree().process_frame

	var fundo: ColorRect = tela.get_node("Fundo") as ColorRect
	afirmar_igual(fundo.color.a, 1.0, "fundo opaco")

	var painel: PanelContainer = tela.get_node("Raiz") as PanelContainer
	var estilo: StyleBoxFlat = painel.get_theme_stylebox("panel") as StyleBoxFlat
	afirmar_nao_nulo(estilo, "o painel tem StyleBox proprio, nao o default semitransparente do tema")
	afirmar_igual(estilo.bg_color.a, 1.0, "e ele e opaco")

	tela.queue_free()
	await get_tree().process_frame


func teste_fase_de_json_entra_em_jogo_sem_cena_propria() -> void:
	var caminho: String = _gravar("zz-teste-jogavel.json", _json_minimo("Jogavel de teste"))
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
	if not afirmar_verdadeiro(resultado.ok(), "a fase de teste carrega (%s)" % resultado.mensagem()):
		return

	Sessao.iniciar()
	var fase: FaseBase = IniciadorDeFase.jogar(get_tree(), resultado.config)
	await get_tree().process_frame

	if not afirmar_nao_nulo(fase, "a fase entrou em cena sem ter .tscn propria"):
		return
	afirmar_falso(fase.aviso.visible, "e nao caiu na tela de configuracao invalida")
	afirmar_igual(fase.configuracao.titulo, "Jogavel de teste", "com a configuracao certa")
	afirmar_tamanho(fase.pacotes, 1, "o terminal do JSON virou pacote no labirinto")
	afirmar_tamanho(fase.cachorros, 1, "e o vigia do JSON virou cachorro")
	# A ligacao com a telemetria: o id do arquivo e o id que a sessao registra.
	afirmar_igual(Sessao.id_fase, resultado.config.id_fase,
		"o id_fase da fase de autoria e o que vai para a telemetria")

	fase.queue_free()
	await get_tree().process_frame


func teste_exportar_e_subir_fazem_round_trip() -> void:
	# Exportar num computador e subir em outro tem que levar a fase INTEIRA --
	# o mapa inclusive, que viaja como semente e nao desenhado.
	var origem: String = _gravar("zz-teste-export.json", _json_minimo("Exportavel"))
	var carregada: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(origem)
	if not afirmar_verdadeiro(carregada.ok(), "a fase de origem carrega"):
		return

	var destino: String = caminho_temporario("exportada.json")
	var erros: PackedStringArray = CarregadorFaseJson.salvar(carregada.config, destino)
	afirmar_igual(erros.size(), 0, "exportar grava sem erro")
	afirmar_verdadeiro(FileAccess.file_exists(destino), "o arquivo de destino existe")

	# "Subir" e ler o arquivo externo e validar antes de aceitar.
	var subida: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(destino)
	if not afirmar_verdadeiro(subida.ok(), "o arquivo exportado sobe de volta (%s)"
			% subida.mensagem()):
		return

	afirmar_igual(subida.config.titulo, carregada.config.titulo, "titulo atravessa")
	afirmar_igual(subida.config.id_fase, carregada.config.id_fase,
		"id_fase atravessa: a telemetria das duas maquinas fala da MESMA fase")
	afirmar_tamanho(subida.config.cachorros, carregada.config.cachorros.size(), "vigias atravessam")
	afirmar_tamanho(subida.config.pacotes, carregada.config.pacotes.size(), "terminais atravessam")
	afirmar_igual(subida.config.mapa.linhas, carregada.config.mapa.linhas,
		"o labirinto e identico do outro lado")


func teste_subir_arquivo_invalido_e_recusado() -> void:
	var ruim: String = caminho_temporario("nao-e-fase.json")
	var arquivo: FileAccess = FileAccess.open(ruim, FileAccess.WRITE)
	arquivo.store_string('{"titulo": "", "terminais": []}')
	arquivo.close()

	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(ruim)
	afirmar_falso(resultado.ok(), "arquivo invalido e recusado na porta, nao depois de copiado")
	afirmar_verdadeiro(resultado.erros.size() >= 1, "com motivo legivel")
