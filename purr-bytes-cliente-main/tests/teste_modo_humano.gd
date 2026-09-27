extends CasoDeTeste

## Mecanicas do MODO HUMANO: cachorros coloridos, cifra certa x cifra errada,
## caixa de puzzle do pacote e porta trancada.
##
## Todas elas sao desligadas por ConfigJogo.modo_treino -- o ultimo teste deste
## arquivo e exatamente essa garantia, porque e ela que mantem o ambiente de
## treino de agente funcionando com o contrato antigo (coleta ao encostar,
## qualquer cifra protege).
##
## Monta uma FaseBase com o fixture de tests/apoio_fase_de_teste.gd (nao ha
## mais fase fixa no projeto -- ADR 0012), na mesma forma que a antiga
## fase_01.tscn: dois cachorros de Cesar, tres pacotes, um desafio.

var _mock: TransporteMock
var _fase: FaseBase
var _modo_treino_original: bool = false


func antes() -> void:
	_modo_treino_original = ConfigJogo.modo_treino
	ConfigJogo.modo_treino = false


func depois() -> void:
	ConfigJogo.modo_treino = _modo_treino_original
	# Puzzle aberto pausa a arvore inteira: deixar a pausa vazar levaria a suite
	# seguinte a rodar com o jogo congelado.
	get_tree().paused = false
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()


func _preparar_mock(sufixo: String) -> TransporteMock:
	var mock := TransporteMock.new(caminho_temporario("humano_mock_%s.jsonl" % sufixo))
	Telemetria.reiniciar(mock, caminho_temporario("humano_fila_%s.json" % sufixo))
	return mock


func _montar_fase() -> FaseBase:
	Sessao.iniciar()
	var fase: FaseBase = ApoioFaseDeTeste.instanciar(ApoioFaseDeTeste.config_cesar())
	add_child(fase)
	return fase


# ---------------------------------------------------------------------------
# Cachorros coloridos
# ---------------------------------------------------------------------------

func teste_fase_tem_dois_cachorros_com_cor_da_legenda() -> void:
	_preparar_mock("cores")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_tamanho(_fase.cachorros, 2, "a fase de teste tem dois cachorros")
	afirmar_igual(_fase.cachorros[0], _fase.cachorro,
		"o cachorro da cena pai continua sendo o numero 1")

	for cachorro: Cachorro in _fase.cachorros:
		afirmar_igual(cachorro.algoritmo_exigido, "CESAR",
			"os dois cachorros do fixture exigem Cesar")
		afirmar_igual(cachorro.cor(), LegendaCores.cor("CESAR"),
			"a cor do cachorro vem de LegendaCores, nao de uma tabela paralela")
		afirmar_igual((cachorro.get_node("Marcador") as MarcadorDeCor).cor, LegendaCores.cor("CESAR"),
			"a cor esta pintada no anel do chao, e nao so guardada numa variavel")

	afirmar_diferente(_fase.cachorros[0].global_position, _fase.cachorros[1].global_position,
		"cada cachorro nasce na celula que o CachorroConfig manda")


## A camada que ENSINAVA "a cor diz qual cifra" saiu (tutorial do menu, HUD
## colorida). O que NAO pode sair junto: a cor do cachorro e o aviso de
## protecao. Este teste e a rede contra perder um deles por descuido.
func teste_o_tutorial_saiu_mas_a_cor_e_o_aviso_de_protecao_ficaram() -> void:
	var menu: Control = load("res://cenas/ui/menu_principal.tscn").instantiate() as Control
	afirmar_nulo(menu.get_node_or_null("PainelTutorial"),
		"o painel de tutorial de cores nao existe mais")
	afirmar_nulo(menu.get_node_or_null("Cartao/Coluna/Botoes/Tutorial"),
		"nem o botao que o abria")
	afirmar_nao_nulo(menu.get_node_or_null("Cartao/Coluna/Botoes/Telemetria"),
		"o botao de telemetria continua no lugar, sem buraco no layout")
	menu.free()

	_preparar_mock("cor_preservada")
	_fase = _montar_fase()
	await get_tree().process_frame

	for cachorro: Cachorro in _fase.cachorros:
		var pintada: Color = (cachorro.get_node("Marcador") as MarcadorDeCor).cor
		afirmar_igual(pintada, cachorro.cor(), "o cachorro continua pintado com a cor dele")
		afirmar_verdadeiro(pintada.a > 0.0, "e a cor e visivel, nao transparente")

	# O aviso de protecao continua informando QUAL cifra esta ativa...
	_fase.jogador.ativar_protecao(10.0, "CESAR")
	await get_tree().process_frame
	var rotulo: Label = _fase.hud.get_node("Raiz/Linha/Protecao") as Label
	afirmar_contem(rotulo.text, "Cesar", "a HUD continua dizendo qual cifra protege")
	# ...mas em cor neutra: a cor deixou de ser codigo semantico.
	afirmar_igual(rotulo.modulate, Color.WHITE, "sem cor semantica no aviso")


func teste_cor_do_cachorro_pode_ser_escolhida_a_mao() -> void:
	var config := CachorroConfig.new()
	config.algoritmo_exigido = "CESAR"
	afirmar_igual(config.cor_efetiva(), LegendaCores.cor("CESAR"),
		"sem escolha, a cor default e a do algoritmo")

	config.cor = Color(1.0, 0.0, 0.5)
	afirmar_igual(config.cor_efetiva(), Color(1.0, 0.0, 0.5),
		"a cor escolhida a mao manda: ela e identidade visual, nao regra")


func teste_cachorro_sem_visao_patrulha_e_nao_persegue_o_jogador() -> void:
	_preparar_mock("patrulha")
	_fase = _montar_fase()
	await get_tree().process_frame

	var cachorro: Cachorro = _fase.cachorros[0]
	cachorro.parar()
	cachorro.global_position = Vector2(4000, 4000)  # longe: sem linha de visao

	var alvo: Vector2 = _fase._alvo_de_perseguicao(cachorro)
	afirmar_diferente(alvo, _fase.jogador.global_position,
		"com ancoras e sem visao, o alvo e a rota de patrulha -- nao a posicao do jogador")

	var ancoras: Array[Vector2i] = _fase._ancoras_de(cachorro)
	afirmar_verdadeiro(ancoras.size() >= 2, "o cachorro tem rota de patrulha configurada")
	afirmar_igual(alvo, _fase._mundo_da_celula(ancoras[0]),
		"o alvo e a primeira ancora da rota")


## Regressao do travamento das fases 2 e 3: o Diretor manda o cachorro para o
## centro de uma regiao e fase_base varre pontos ao redor (+-1 celula). Nada
## garantia que esses pontos caissem em piso -- caindo em parede, o A* devolvia
## caminho vazio, o cachorro parava, e o indice da varredura so avancaria quando
## ele CHEGASSE ao ponto. Travava para sempre.
func teste_alvo_de_varredura_nunca_cai_em_parede() -> void:
	_preparar_mock("varredura")
	Sessao.iniciar()
	_fase = ApoioFaseDeTeste.instanciar(ApoioFaseDeTeste.config_cesar())
	ApoioFaseDeTeste.adicionar_regioes(_fase, [
		Vector2(48, 48), Vector2(240, 48), Vector2(240, 176), Vector2(48, 176),
	])
	add_child(_fase)
	await get_tree().process_frame

	if not afirmar_nao_nulo(_fase._diretor, "fase com regioes tem Diretor"):
		return

	var cachorro: Cachorro = _fase.cachorros[0]
	cachorro.parar()
	cachorro.global_position = Vector2(4000, 4000)  # longe: sem linha de visao

	# Percorre a tabela de varredura inteira, em todas as regioes.
	for regiao_indice: int in _fase.regioes_no.get_child_count():
		var regiao: Area2D = _fase.regioes_no.get_child(regiao_indice) as Area2D
		for _passo: int in 8:
			var alvo: Vector2 = _fase._alvo_de_varredura(cachorro, regiao)
			if not _fase._navegacao.ponto_e_andavel(alvo):
				falhar("alvo de varredura %s caiu em parede" % alvo)
				return
			_fase._indice_varredura += 1

	afirmar_verdadeiro(true, "todo alvo de varredura cai em celula livre, em todas as regioes")


func teste_cachorro_alcanca_o_outro_lado_do_labirinto() -> void:
	_preparar_mock("travessia")
	_fase = _montar_fase()
	await get_tree().process_frame

	# Cachorro na entrada, alvo na porta: o caminho tem que existir e ser
	# valido celula a celula. E o teste que prova que o mapa nao tem buraco
	# entre os dois extremos.
	var cachorro: Cachorro = _fase.cachorros[0]
	cachorro.parar()
	cachorro.global_position = _fase.ponto_de_entrada.global_position

	var caminho: PackedVector2Array = _fase._navegacao.calcular_caminho(
		cachorro.global_position, _fase.ponto_de_saida.global_position)

	if not afirmar_verdadeiro(caminho.size() > 1, "existe caminho da entrada ate a porta"):
		return
	for ponto: Vector2 in caminho:
		if not _fase._navegacao.ponto_e_andavel(ponto):
			falhar("o caminho passa por parede em %s" % ponto)
			return
	afirmar_verdadeiro(true, "nenhum waypoint do caminho cai em parede")


func teste_ponto_em_parede_e_corrigido_para_a_celula_livre_mais_proxima() -> void:
	_preparar_mock("snap")
	_fase = _montar_fase()
	await get_tree().process_frame

	# (0,0) e sempre parede: e a quina da borda externa.
	var parede: Vector2 = _fase._mundo_da_celula(Vector2i(0, 0))
	afirmar_falso(_fase._navegacao.ponto_e_andavel(parede), "o ponto escolhido e parede mesmo")

	var corrigido: Vector2 = _fase._navegacao.ponto_andavel_mais_proximo(parede)
	afirmar_verdadeiro(_fase._navegacao.ponto_e_andavel(corrigido),
		"a correcao devolve uma celula livre")
	afirmar_verdadeiro(parede.distance_to(corrigido) <= 32.0,
		"e a mais proxima, nao um ponto qualquer do mapa")


# ---------------------------------------------------------------------------
# Terminal: pausa
# ---------------------------------------------------------------------------

func teste_terminal_pausa_e_despausa_o_jogo() -> void:
	_preparar_mock("pausa_terminal")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_falso(get_tree().paused, "o jogo comeca rodando")

	_fase.terminal.abrir()
	afirmar_verdadeiro(get_tree().paused,
		"abrir o terminal pausa: digitar 'cifrar' fugindo mede digitacao, nao aprendizado")

	_fase.terminal.fechar()
	afirmar_falso(get_tree().paused, "fechar o terminal devolve o jogo ao movimento")


func teste_protecao_nao_consome_tempo_com_o_jogo_pausado() -> void:
	_preparar_mock("pausa_protecao")
	_fase = _montar_fase()
	await get_tree().process_frame

	_fase.jogador.ativar_protecao(10.0, "CESAR")
	_fase.terminal.abrir()

	# A contagem da protecao corre em Jogador._physics_process, que nao roda
	# pausado -- entao ler o terminal com calma nao custa cifra.
	var restante_antes: float = _fase.jogador._restante_de_protecao_s
	for _quadro: int in 8:
		await get_tree().physics_frame
	afirmar_igual(_fase.jogador._restante_de_protecao_s, restante_antes,
		"a protecao nao anda enquanto o terminal esta aberto")

	_fase.terminal.fechar()


# ---------------------------------------------------------------------------
# Cifra certa x cifra errada
# ---------------------------------------------------------------------------

func teste_cifra_da_cor_errada_nao_protege() -> void:
	_preparar_mock("cifra_errada")
	_fase = _montar_fase()
	await get_tree().process_frame

	var cachorro: Cachorro = _fase.cachorros[0]  # exige CESAR

	_fase.jogador.ativar_protecao(30.0, "VIGENERE")
	afirmar_verdadeiro(_fase.jogador.protecao_ativa, "ha cifra ativa")
	afirmar_falso(_fase._protegido_contra(cachorro),
		"cifra de Vigenere nao engana um cachorro que le Cesar")

	_fase.jogador.ativar_protecao(30.0, "CESAR")
	afirmar_verdadeiro(_fase._protegido_contra(cachorro),
		"a cifra da cor certa protege")

	_fase.jogador.cancelar_protecao()
	afirmar_falso(_fase._protegido_contra(cachorro), "texto claro nunca protege")


func teste_captura_com_cifra_errada_perde_vida_e_registra_o_cachorro() -> void:
	_mock = _preparar_mock("captura_errada")
	_fase = _montar_fase()
	await get_tree().process_frame

	var cachorro: Cachorro = _fase.cachorros[0]
	_fase.jogador.ativar_protecao(30.0, "VIGENERE")

	var vidas_antes: int = Sessao.vidas
	cachorro.parar()
	cachorro.global_position = _fase.jogador.global_position

	var capturado: bool = false
	for _tentativa: int in 10:
		await get_tree().physics_frame
		if Sessao.vidas < vidas_antes:
			capturado = true
			break
	afirmar_verdadeiro(capturado, "cifra da cor errada nao impede a interceptacao")

	cachorro.global_position = Vector2(4000, 4000)
	await Telemetria.descarregar()

	var capturas: Array[Dictionary] = _eventos_do_tipo(CatalogoEventos.JOGADOR_CAPTURADO)
	if not afirmar_verdadeiro(capturas.size() >= 1, "JOGADOR_CAPTURADO emitido"):
		return
	var payload: Dictionary = capturas[0]["payload"] as Dictionary
	afirmar_igual(String(payload["algoritmo_exigido"]), "CESAR",
		"o evento diz qual cifra teria protegido")
	afirmar_igual(String(payload["algoritmo_protegido"]), "VIGENERE",
		"e qual o jogador tinha ativa -- e a diferenca entre as duas que vira dado de analise")


func teste_resolver_desafio_protege_na_cifra_do_desafio() -> void:
	_preparar_mock("protecao_do_desafio")
	_fase = _montar_fase()
	await get_tree().process_frame

	_fase.terminal.comando_submetido.emit("cifrar pacote chave=3", 900)

	afirmar_verdadeiro(_fase.jogador.protecao_ativa, "o acerto ativa a protecao")
	afirmar_igual(_fase.jogador.algoritmo_protegido, "CESAR",
		"a protecao carrega o algoritmo do desafio resolvido")
	afirmar_verdadeiro(_fase._protegido_contra(_fase.cachorros[0]),
		"e por isso protege do cachorro verde")


# ---------------------------------------------------------------------------
# Caixa de puzzle do pacote
# ---------------------------------------------------------------------------

func teste_pacote_abre_a_caixa_e_so_coleta_com_a_resposta_certa() -> void:
	_mock = _preparar_mock("puzzle")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_tamanho(_fase.pacotes, 3, "a fase de teste tem tres pacotes")
	var pacote: Pacote = _fase.pacotes[0]

	_fase._ao_alcancar_pacote(pacote)
	afirmar_verdadeiro(_fase.caixa_puzzle.esta_aberta(), "encostar no pacote abre a caixa")
	afirmar_verdadeiro(get_tree().paused, "a caixa pausa o jogo: ninguem e capturado lendo enunciado")
	afirmar_falso(pacote.coletado, "o pacote ainda nao foi coletado")

	# Resposta errada: nao coleta, nao fecha, custa pontos. O placar comeca em
	# zero e Sessao.somar_pontos nunca deixa ficar negativo (secao 7: o erro e
	# custo pedagogico, nao humilhacao), entao o teste precisa de saldo para a
	# penalidade ter onde aparecer.
	Sessao.somar_pontos(200)
	var pontos_antes: int = Sessao.pontuacao
	_fase.caixa_puzzle.escolher(_opcao_errada(pacote.configuracao))
	afirmar_falso(pacote.coletado, "resposta errada nao coleta o pacote")
	afirmar_verdadeiro(_fase.caixa_puzzle.esta_aberta(), "a caixa continua aberta para nova tentativa")
	afirmar_verdadeiro(Sessao.pontuacao < pontos_antes, "errar custa pontos")

	# Resposta certa: coleta, fecha, despausa.
	_fase.caixa_puzzle.escolher(pacote.configuracao.resposta_correta)
	afirmar_verdadeiro(pacote.coletado, "resposta certa coleta o pacote")
	afirmar_falso(_fase.caixa_puzzle.esta_aberta(), "a caixa fecha")
	afirmar_falso(get_tree().paused, "o jogo volta a rodar")

	await Telemetria.descarregar()
	var tentativas: Array[Dictionary] = _tentativas_do_desafio(
		"pacote-%s" % pacote.configuracao.identificador)
	afirmar_tamanho(tentativas, 2, "erro e acerto viram uma tentativa_comando cada")
	afirmar_igual(String(tentativas[0]["resultado"]), CatalogoResultados.ERRO_SEMANTICO,
		"escolher a ferramenta errada e erro semantico: estrutura valida, significado invalido")
	afirmar_igual(String(tentativas[1]["resultado"]), CatalogoResultados.SUCESSO, "depois, acerto")
	afirmar_igual(int(tentativas[1]["numero_tentativa"]), 2,
		"a segunda tentativa do mesmo pacote e numerada como tal")


func teste_cancelar_a_caixa_despausa_sem_coletar() -> void:
	_preparar_mock("puzzle_cancelado")
	_fase = _montar_fase()
	await get_tree().process_frame

	var pacote: Pacote = _fase.pacotes[0]
	_fase._ao_alcancar_pacote(pacote)
	_fase.caixa_puzzle.cancelada.emit()

	afirmar_falso(get_tree().paused, "sair da caixa despausa o jogo")
	afirmar_falso(pacote.coletado, "sair sem responder nao coleta -- a porta continua trancada")


func teste_opcoes_sao_embaralhadas_sem_perder_nem_inventar() -> void:
	_preparar_mock("embaralha")
	_fase = _montar_fase()
	await get_tree().process_frame

	var pacote: Pacote = _fase.pacotes[0]
	var esperadas: PackedStringArray = pacote.configuracao.opcoes

	var ordens: Dictionary = {}
	for _repeticao: int in 24:
		_fase.caixa_puzzle.abrir(pacote.configuracao)
		var ordem: PackedStringArray = _fase.caixa_puzzle.ordem_das_opcoes()

		afirmar_igual(ordem.size(), esperadas.size(), "nenhuma opcao some no embaralhamento")
		for opcao: String in esperadas:
			if not ordem.has(opcao):
				falhar("opcao '%s' sumiu do painel" % opcao)
				break
		ordens["|".join(ordem)] = true

	_fase.caixa_puzzle.fechar()
	# 24 aberturas de uma lista de 3 caindo sempre na MESMA ordem seria
	# 1 em 3^23 por acaso -- na pratica, so acontece se nao houver sorteio.
	afirmar_verdadeiro(ordens.size() >= 2,
		"a ordem das opcoes muda entre aberturas: a resposta certa nao fica sempre no mesmo botao")


## A cor e a pista do LABIRINTO. Dentro da caixa ela viraria muleta: bastaria
## parear a cor do botao com a do cachorro que acabou de passar para acertar sem
## entender nada -- e e justamente o entendimento que o puzzle mede.
func teste_nenhuma_opcao_do_puzzle_e_colorida() -> void:
	_preparar_mock("sem_cor")
	_fase = _montar_fase()
	await get_tree().process_frame

	for pacote: Pacote in _fase.pacotes:
		_fase.caixa_puzzle.abrir(pacote.configuracao)
		for filho: Node in _fase.caixa_puzzle._opcoes.get_children():
			var botao := filho as Button
			if botao == null:
				continue
			if botao.has_theme_color_override("font_color"):
				falhar("o botao '%s' esta colorido: a cor entregaria a resposta" % botao.text)
				return
	_fase.caixa_puzzle.fechar()
	afirmar_verdadeiro(true, "todos os botoes de resposta sao neutros")


func teste_perguntas_se_embaralham_entre_as_posicoes_da_fase() -> void:
	_preparar_mock("posicoes")

	var identificadores_por_posicao: Dictionary = {}
	for _repeticao: int in 12:
		var fase: FaseBase = _montar_fase()
		await get_tree().process_frame

		var chave := PackedStringArray()
		for pacote: Pacote in fase.pacotes:
			chave.append(pacote.configuracao.identificador)
		identificadores_por_posicao["|".join(chave)] = true

		# Todas as perguntas da fase aparecem SEMPRE: o que muda e onde cada uma
		# cai, nunca quais o participante recebe -- instrumento igual para todos.
		afirmar_igual(chave.size(), fase.configuracao.pacotes.size(),
			"todos os pacotes da fase estao em cena")

		fase.queue_free()
		if Sessao.ativa:
			Sessao.encerrar()
		await get_tree().process_frame

	afirmar_verdadeiro(identificadores_por_posicao.size() >= 2,
		"as perguntas trocam de posicao entre partidas")


# ---------------------------------------------------------------------------
# Porta
# ---------------------------------------------------------------------------

func teste_porta_so_abre_com_todos_os_pacotes() -> void:
	_preparar_mock("porta")
	_fase = _montar_fase()
	await get_tree().process_frame

	afirmar_verdadeiro(_fase.ponto_de_saida.trancada, "a porta nasce trancada")

	# Chegar na porta sem os pacotes nao conclui a fase.
	_fase._ao_chegar_na_saida(_fase.jogador)
	afirmar_falso(_fase._encerrada, "porta trancada nao encerra a fase")

	for pacote: Pacote in _fase.pacotes:
		_fase._coletar_pacote(pacote)

	afirmar_falso(_fase.ponto_de_saida.trancada, "com todos os pacotes, a porta abre")
	afirmar_falso(_fase._porta_trancada(), "e o estado interno concorda com o visual")


# ---------------------------------------------------------------------------
# Modo de treino: as mecanicas humanas saem de cena
# ---------------------------------------------------------------------------

func teste_modo_treino_coleta_direto_e_aceita_qualquer_cifra() -> void:
	ConfigJogo.modo_treino = true
	_preparar_mock("treino")
	_fase = _montar_fase()
	await get_tree().process_frame

	var pacote: Pacote = _fase.pacotes[0]
	_fase._ao_alcancar_pacote(pacote)

	afirmar_falso(_fase.caixa_puzzle.esta_aberta(), "em treino a caixa nao abre")
	afirmar_falso(get_tree().paused, "e o jogo nao pausa")
	afirmar_verdadeiro(pacote.coletado, "o pacote e coletado ao encostar, como no contrato antigo")

	_fase.jogador.ativar_protecao(30.0, "VIGENERE")
	afirmar_verdadeiro(_fase._protegido_contra(_fase.cachorros[0]),
		"em treino qualquer cifra ativa protege: a regra de cores e do modo humano")


# ---------------------------------------------------------------------------
# Configuracao: cachorro impossivel de enganar e erro de fase
# ---------------------------------------------------------------------------

func teste_fase_recusa_cachorro_de_cifra_indisponivel() -> void:
	var config := FaseConfig.new()
	config.numero = 1
	config.titulo = "fase de teste"
	config.algoritmo = "CESAR"
	config.verbos_permitidos = PackedStringArray(["cifrar", "dica", "status"])

	var desafio := DesafioConfig.new()
	desafio.identificador = "cesar-01"
	desafio.verbo_esperado = "cifrar"
	desafio.chave_esperada = "3"
	config.desafios = [desafio]

	var impossivel := CachorroConfig.new()
	impossivel.identificador = "azul-injusto"
	impossivel.algoritmo_exigido = "VIGENERE"
	config.cachorros = [impossivel]

	var problemas: PackedStringArray = config.problemas()
	afirmar_verdadeiro(problemas.size() >= 1,
		"um cachorro que exige cifra que a fase nao ensina reprova a configuracao")
	afirmar_contem(" ".join(problemas), "azul-injusto",
		"a mensagem diz qual cachorro esta injusto")

	var justo := CachorroConfig.new()
	justo.identificador = "verde-justo"
	justo.algoritmo_exigido = "CESAR"
	config.cachorros = [justo]
	afirmar_igual(config.problemas().size(), 0, "com a cifra disponivel, a fase e valida")


# ---------------------------------------------------------------------------
# Apoio
# ---------------------------------------------------------------------------

func _opcao_errada(config: PacoteConfig) -> String:
	for opcao: String in config.opcoes:
		if opcao != config.resposta_correta:
			return opcao
	return ""


func _registros() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if _mock == null or not FileAccess.file_exists(_mock.caminho()):
		return saida
	var arquivo: FileAccess = FileAccess.open(_mock.caminho(), FileAccess.READ)
	while not arquivo.eof_reached():
		var linha: String = arquivo.get_line().strip_edges()
		if linha.is_empty():
			continue
		var lido: Variant = JSON.parse_string(linha)
		if typeof(lido) == TYPE_DICTIONARY:
			saida.append(lido as Dictionary)
	arquivo.close()
	return saida


func _eventos_do_tipo(tipo: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for registro: Dictionary in _registros():
		if String(registro.get("tipo_registro", "")) != "evento":
			continue
		var dados: Dictionary = registro["dados"] as Dictionary
		if String(dados.get("tipo_evento", "")) == tipo:
			saida.append(dados)
	return saida


func _tentativas_do_desafio(identificador: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for registro: Dictionary in _registros():
		if String(registro.get("tipo_registro", "")) != "tentativa":
			continue
		var dados: Dictionary = registro["dados"] as Dictionary
		if String(dados.get("desafio", "")) == identificador:
			saida.append(dados)
	return saida
