extends CasoDeTeste

## Cobre "uma fase real roda" pelo caminho canonico agora que nao ha mais fase
## fixa no projeto (ADR 0012: o jogo virou ferramenta de autoria).
##
## Carrega a MESMA fase de exemplo que CarregadorFaseJson.semear_exemplo()
## grava no primeiro boot -- o mesmo dicionario, so que sem depender do
## arquivo em disco (user://fases/ e estado compartilhado entre arquivos de
## teste; um teste hermetico nao pode presumir se a pasta ja foi semeada) -- e
## roda pelo MESMO IniciadorDeFase que selecao_de_fases.gd usa para abrir
## qualquer fase de autoria (ja coberto, para um JSON generico, por
## tests/teste_selecao_de_fases.gd::teste_fase_de_json_entra_em_jogo_sem_cena_propria).
##
## Substitui tests/teste_fase_0{1,2,3}_integracao.gd e
## tests/teste_encadeamento_de_fases.gd. A fase de exemplo bloqueia por
## COMANDO livre, nao por desafio de terminal (fase de autoria nunca declara
## DesafioConfig -- ver CarregadorFaseJson.de_texto()), entao o pipeline
## AFD/parser/resolvedor continua coberto por unidade
## (tests/teste_analisador_*.gd, tests/teste_resolvedor_comando.gd,
## tests/teste_cesar.gd) e nao repetido aqui.

var _mock: TransporteMock
var _fase: FaseBase


func _preparar_mock(sufixo: String) -> TransporteMock:
	var mock := TransporteMock.new(caminho_temporario("fase_exemplo_mock_%s.jsonl" % sufixo))
	Telemetria.reiniciar(mock, caminho_temporario("fase_exemplo_fila_%s.json" % sufixo))
	return mock


func depois() -> void:
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()


func _config_de_exemplo() -> FaseConfig:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		JSON.stringify(CarregadorFaseJson._exemplo()))
	return resultado.config


func _montar_fase() -> FaseBase:
	Sessao.iniciar()
	return IniciadorDeFase.jogar(get_tree(), _config_de_exemplo())


func teste_fase_de_exemplo_carrega_configurada_e_jogavel() -> void:
	_preparar_mock("carrega")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_nao_nulo(_fase, "a fase de exemplo entra em cena sem ter .tscn propria")
	afirmar_falso(_fase.aviso.visible, "a fase de exemplo e valida")
	afirmar_tamanho(_fase.cachorros, 4, "quatro vigias: dois de comando, um de cifra de Cesar e um que so persegue")
	afirmar_tamanho(_fase.pacotes, 3, "tres terminais viram pacote")


func teste_comando_de_bloqueio_protege_contra_o_vigia_certo() -> void:
	_preparar_mock("comando")
	_fase = _montar_fase()
	await get_tree().process_frame

	var vigia: Cachorro = _fase.cachorros[0]  # comando "trocar senha"
	_fase.terminal.comando_submetido.emit("trocar senha", 800)

	afirmar_verdadeiro(_fase.jogador.protecao_ativa, "o comando aceito ativa a protecao")
	afirmar_verdadeiro(_fase._protegido_contra(vigia),
		"e protege exatamente o vigia daquele comando")

	var vigia_que_so_persegue: Cachorro = _fase.cachorros[2]
	afirmar_falso(_fase._protegido_contra(vigia_que_so_persegue),
		"o vigia sem comando (so persegue) nao e enganado por nenhuma protecao")


func teste_partida_completa_emite_sequencia_esperada() -> void:
	_mock = _preparar_mock("completa")
	_fase = _montar_fase()
	await get_tree().process_frame

	# Comando que nao bloqueia nenhum vigia, mas ainda passa pelo pipeline
	# lexico-sintatico normal do terminal.
	_fase.terminal.comando_submetido.emit("cifrar pacote!", 400)  # ERRO_LEXICO

	# Captura em texto claro: nenhum comando de bloqueio foi aceito ainda.
	var vidas_antes: int = Sessao.vidas
	var vigia: Cachorro = _fase.cachorros[0]
	vigia.parar()
	vigia.global_position = _fase.jogador.global_position
	var capturado: bool = false
	for _tentativa: int in 10:
		await get_tree().physics_frame
		if Sessao.vidas < vidas_antes:
			capturado = true
			break
	afirmar_verdadeiro(capturado, "vigia capturou o jogador em texto claro")

	vigia.global_position = Vector2(4000, 4000)
	_fase.tela_captura.encerrada.emit()
	await get_tree().process_frame

	# Agora o comando certo protege.
	_fase.terminal.comando_submetido.emit("trocar senha", 1200)

	# Coleta os tres pacotes pela caixa de puzzle, respondendo certo em cada.
	for pacote: Pacote in _fase.pacotes.duplicate():
		_fase._ao_alcancar_pacote(pacote)
		_fase.caixa_puzzle.escolher(pacote.configuracao.resposta_correta)

	afirmar_falso(_fase._porta_trancada(), "com os tres pacotes, a porta abre")

	_fase.concluir()
	await get_tree().process_frame
	await get_tree().process_frame

	# change_scene_to_file() so gerencia o no que ELE proprio rastreia como
	# current_scene -- IniciadorDeFase.jogar ja deixou `_fase` nesse papel, e
	# concluir() troca para o menu. O menu novo fica sob root processando para
	# sempre se ninguem o liberar (mesmo vazamento documentado no antigo
	# tests/teste_encadeamento_de_fases.gd).
	var cena_apos_concluir: Node = get_tree().current_scene
	afirmar_falso(cena_apos_concluir is FaseBase,
		"concluir a fase de exemplo volta ao menu -- nao ha proxima fase fixa")
	if is_instance_valid(cena_apos_concluir) and cena_apos_concluir != _fase:
		cena_apos_concluir.queue_free()
		await get_tree().process_frame

	await Telemetria.descarregar()

	var registros: Array[Dictionary] = _ler_jsonl(_mock.caminho())
	var eventos: Array[Dictionary] = _filtrar(registros, "evento")
	var tipos: PackedStringArray = _tipos(eventos)

	for esperado: String in [
		CatalogoEventos.SESSAO_INICIADA, CatalogoEventos.FASE_INICIADA,
		CatalogoEventos.ERRO_LEXICO, CatalogoEventos.JOGADOR_CAPTURADO,
		CatalogoEventos.FASE_CONCLUIDA,
	]:
		afirmar_verdadeiro(tipos.has(esperado), "sequencia contem %s" % esperado)

	_afirmar_sequencia_sem_lacuna(eventos)


# ---------------------------------------------------------------------------
# Apoio (mesma leitura de .jsonl que tests/teste_telemetria.gd usa)
# ---------------------------------------------------------------------------

func _ler_jsonl(caminho: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if not FileAccess.file_exists(caminho):
		falhar("arquivo do modo MOCK nao foi criado: %s" % caminho)
		return saida
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.READ)
	while not arquivo.eof_reached():
		var linha: String = arquivo.get_line().strip_edges()
		if linha.is_empty():
			continue
		var lido: Variant = JSON.parse_string(linha)
		if typeof(lido) != TYPE_DICTIONARY:
			continue
		saida.append(lido as Dictionary)
	arquivo.close()
	return saida


func _filtrar(registros: Array[Dictionary], tipo: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for registro: Dictionary in registros:
		if String(registro.get("tipo_registro", "")) == tipo:
			saida.append(registro["dados"] as Dictionary)
	return saida


func _tipos(eventos: Array[Dictionary]) -> PackedStringArray:
	var saida := PackedStringArray()
	for evento: Dictionary in eventos:
		saida.append(String(evento["tipo_evento"]))
	return saida


func _afirmar_sequencia_sem_lacuna(eventos: Array[Dictionary]) -> void:
	var esperada: int = 0
	for evento: Dictionary in eventos:
		var sequencia: int = int(evento["sequencia"])
		if sequencia != esperada:
			falhar("lacuna na sequencia: esperado %d, obtido %d (evento %s)"
				% [esperada, sequencia, evento["tipo_evento"]])
			return
		esperada += 1
	afirmar_verdadeiro(true, "sequencia contigua de 0 a %d" % maxi(0, esperada - 1))
