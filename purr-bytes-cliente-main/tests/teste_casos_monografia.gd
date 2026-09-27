extends CasoDeTeste

## Quadro 1 da monografia (Matriz de Casos de Teste Estrutural), TC-01 a TC-04,
## rodando na fase de exemplo -- a fase que o jogo entrega pronta.
##
## Cada teste reproduz a "Condicao e Entrada" do quadro e confere o "Resultado
## Esperado pelo Sistema". E o que permite dizer na defesa que o quadro nao e
## so um registro manual: ele roda a cada execucao da suite.

var _fase: FaseBase = null
var _eventos: Array[Dictionary] = []
var _tentativas: Array[Dictionary] = []


func antes() -> void:
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("quadro1.jsonl")),
		caminho_temporario("quadro1_fila.json"))
	Sessao.iniciar()
	_eventos.clear()
	_tentativas.clear()
	Telemetria.evento_registrado.connect(_ao_evento)
	Telemetria.tentativa_registrada.connect(_ao_tentativa)
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		JSON.stringify(CarregadorFaseJson._exemplo()))
	_fase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame


func depois() -> void:
	Telemetria.evento_registrado.disconnect(_ao_evento)
	Telemetria.tentativa_registrada.disconnect(_ao_tentativa)
	for acao: String in ["mover_direita", "mover_esquerda", "mover_cima", "mover_baixo"]:
		Input.action_release(acao)
	get_tree().paused = false
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()
	await get_tree().process_frame


func _ao_evento(evento: Dictionary) -> void:
	_eventos.append(evento)


func _ao_tentativa(tentativa: Dictionary) -> void:
	_tentativas.append(tentativa)


func _vigia_de_cesar() -> Cachorro:
	for alvo: Cachorro in _fase.cachorros:
		if not alvo.bloqueia_por_comando() and not _fase._apenas_persegue(alvo):
			return alvo
	return null


## Tira os cachorros do caminho: o TC-01 mede so colisao com parede.
func _afastar_cachorros() -> void:
	for alvo: Cachorro in _fase.cachorros:
		alvo.parar()
		alvo.process_mode = Node.PROCESS_MODE_DISABLED
		alvo.global_position = Vector2(-10000, -10000)


func teste_tc01_colisao_estatica_bloqueia_o_jogador_na_parede() -> void:
	_afastar_cachorros()
	var mapa: MapaConfig = _fase.configuracao.mapa
	# Uma celula livre com parede logo a direita.
	var partida := Vector2i(-1, -1)
	for y: int in mapa.altura():
		for x: int in mapa.largura() - 1:
			var aqui := Vector2i(x, y)
			if mapa.caractere(aqui) != MapaConfig.PAREDE \
					and mapa.caractere(aqui + Vector2i.RIGHT) == MapaConfig.PAREDE:
				partida = aqui
				break
		if partida.x >= 0:
			break
	if not afirmar_verdadeiro(partida.x >= 0, "o mapa tem uma celula livre encostada em parede"):
		return

	var inicio: Vector2 = _fase._mundo_da_celula(partida)
	var parede: Vector2 = _fase._mundo_da_celula(partida + Vector2i.RIGHT)
	_fase.jogador.reposicionar(inicio)

	# Condicao e entrada: movimentacao direcional contra a parede.
	Input.action_press("mover_direita")
	for i: int in 60:
		await get_tree().physics_frame
	Input.action_release("mover_direita")

	var metade_do_tile: float = 8.0
	afirmar_verdadeiro(_fase.jogador.global_position.x < parede.x - metade_do_tile + 0.5,
		"TC-01: o personagem nao transpoe o limite da celula de parede (x=%.1f, parede comeca em %.1f)"
			% [_fase.jogador.global_position.x, parede.x - metade_do_tile])
	afirmar_verdadeiro(_fase.jogador.global_position.x > inicio.x,
		"e o movimento aconteceu de fato (o teste nao passou por o jogador estar parado)")


func teste_tc02_texto_claro_encostado_no_vigia_e_interceptado() -> void:
	var verde: Cachorro = _vigia_de_cesar()
	var vidas_antes: int = Sessao.vidas
	afirmar_falso(_fase.jogador.protecao_ativa, "condicao: sem comando de criptografia ativo")

	_fase._ao_encostar_no_jogador(_fase.jogador, verde)

	afirmar_igual(Sessao.vidas, vidas_antes - 1, "TC-02: interceptacao custa uma vida (nao e game over)")
	afirmar_verdadeiro(_fase.tela_captura.visible, "e exibe o alerta de dados vazados")
	# "Pausa no laco principal" do quadro: a acao congela -- o jogador perde o
	# controle e todo cachorro para -- enquanto a tela de captura explica.
	afirmar_falso(_fase.jogador._entrada_habilitada, "o jogador para de responder ao controle")
	for alvo: Cachorro in _fase.cachorros:
		afirmar_igual(alvo.caminho_atual().size(), 0, "e nenhum cachorro continua andando")
	var capturas: int = _eventos.filter(func(e: Dictionary) -> bool:
		return e.get("tipo_evento") == CatalogoEventos.JOGADOR_CAPTURADO).size()
	afirmar_igual(capturas, 1, "e registra JOGADOR_CAPTURADO na telemetria")


func teste_tc03_comando_cifrar_validado_deixa_passar_ileso() -> void:
	var verde: Cachorro = _vigia_de_cesar()
	var vidas_antes: int = Sessao.vidas

	_fase._ao_submeter_comando("cifrar senha chave=3", 1000)
	_fase._ao_encostar_no_jogador(_fase.jogador, verde)

	afirmar_igual(_tentativas[0]["resultado"], CatalogoResultados.SUCESSO,
		"o analisador valida o comando cifrar")
	afirmar_igual(Sessao.vidas, vidas_antes, "TC-03: o personagem transita ileso")
	afirmar_falso(_fase.tela_captura.visible, "sem alerta de interceptacao")


func teste_tc04_cyfrar_e_rejeitado_com_erro_de_sintaxe() -> void:
	_fase._ao_submeter_comando("cyfrar senha chave=3", 1000)

	afirmar_falso(_fase.jogador.protecao_ativa, "TC-04: status de texto claro mantido")
	afirmar_igual(_tentativas[0]["resultado"], CatalogoResultados.ERRO_SINTATICO,
		"rejeicao registrada como erro de sintaxe")
	var erros: int = _eventos.filter(func(e: Dictionary) -> bool:
		return e.get("tipo_evento") == CatalogoEventos.ERRO_SINTATICO).size()
	afirmar_igual(erros, 1, "e o evento ERRO_SINTATICO vai para a telemetria")
