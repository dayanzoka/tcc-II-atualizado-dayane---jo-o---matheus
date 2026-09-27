extends CasoDeTeste

## Critério de aceite do Marco 3 (seção 8 do CLAUDE.md): "eco derrubado no
## meio da partida -> jogo continua sem travar, fila cresce, eco volta, fila
## drena, zero evento duplicado e zero perdido". Mata o PROCESSO real do
## servidor de eco (não um mock de falha) para exercitar a pilha de rede de
## verdade -- é a diferença entre este arquivo e
## tests/teste_telemetria.gd::teste_falha_transitoria_preserva_a_fila, que já
## cobre a mesma lógica com um TransporteTelemetria falso.

const PORTA: int = 8092

var _caminho_log: String
var _pid: int = -1
var _lote_original: int
var _intervalo_original: float
var _nivel_original: String


func antes() -> void:
	_lote_original = ConfigJogo.tamanho_lote
	_intervalo_original = ConfigJogo.intervalo_envio_s
	_nivel_original = Registro.nome_do_nivel()
	Registro.definir_nivel_por_nome("SILENCIO")
	# Backoff curto: o teste chama descarregar() direto (sem esperar o Timer),
	# entao isto so importa para o proprio _agendar_retentativa nao crescer
	# demais entre chamadas -- velocidade do teste, nao do produto.
	ConfigJogo.intervalo_envio_s = 0.1

	_caminho_log = caminho_temporario("eco_resiliencia.jsonl")
	_pid = ApoioServidorEco.iniciar(PORTA, _caminho_log)


func depois() -> void:
	ApoioServidorEco.parar(_pid)
	ConfigJogo.tamanho_lote = _lote_original
	ConfigJogo.intervalo_envio_s = _intervalo_original
	Registro.definir_nivel_por_nome(_nivel_original)


func teste_eco_derrubado_no_meio_da_partida_nao_perde_nem_duplica() -> void:
	var pronto: bool = await ApoioServidorEco.aguardar_pronto(get_tree(), PORTA)
	if not afirmar_verdadeiro(pronto, "servidor de eco no ar antes do teste comecar"):
		return
	ApoioServidorEco.limpar_log(_caminho_log)

	var transporte := TransporteHttp.new("http://127.0.0.1:%d" % PORTA, "chave-resiliencia")
	Telemetria.reiniciar(transporte, caminho_temporario("eco_resiliencia_fila.json"))

	var id_sessao: String = Identificador.uuid_v4()
	Telemetria.iniciar_sessao(id_sessao, Identificador.uuid_v4())
	for i: int in 5:
		Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO,
			{"fase_da_queda": "antes", "indice": i}, 1)
	await _drenar_o_que_der(20)
	afirmar_verdadeiro(Telemetria.fila_vazia(), "os primeiros eventos saem normalmente com o eco no ar")

	# O eco cai no meio da partida -- processo real morto, nao uma falha simulada.
	ApoioServidorEco.parar(_pid)
	await get_tree().create_timer(0.2).timeout  # tempo real para a porta ficar livre

	for i: int in 5:
		Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO,
			{"fase_da_queda": "durante", "indice": i}, 1)
	for tentativa: int in 5:
		await Telemetria.descarregar()

	afirmar_falso(Telemetria.fila_vazia(),
		"sem servidor no ar, os eventos ficam presos na fila -- o jogo nao trava nem descarta")
	afirmar_igual(int(Telemetria.estatisticas()["itens_descartados"]), 0,
		"falha de rede e transitoria: nada e descartado so porque o eco esta fora")
	afirmar_verdadeiro(int(Telemetria.estatisticas()["falhas_consecutivas"]) > 0,
		"as tentativas fracassadas contam para o backoff")

	# O eco volta -- MESMA porta, MESMO arquivo de log (log NAO e limpo: o
	# teste precisa do historico de antes e depois da queda no mesmo lugar).
	_pid = ApoioServidorEco.iniciar(PORTA, _caminho_log, false)
	var voltou: bool = await ApoioServidorEco.aguardar_pronto(get_tree(), PORTA)
	if not afirmar_verdadeiro(voltou, "servidor de eco volta ao ar na mesma porta"):
		return

	await _drenar_o_que_der(60)
	Telemetria.encerrar_sessao()
	await _drenar_o_que_der(20)

	afirmar_verdadeiro(Telemetria.fila_vazia(), "a fila drena por completo depois que o eco volta")
	afirmar_igual(int(Telemetria.estatisticas()["itens_descartados"]), 0,
		"do inicio ao fim, zero item descartado")

	var ids_de_evento: Dictionary = {}
	var duplicados: int = 0
	for registro: Dictionary in ApoioServidorEco.ler_log(_caminho_log):
		# aguardar_pronto() manda uma sonda sem cabecalho -- nao e uma
		# requisicao real de Telemetria, entao nao entra na contagem.
		if String(registro.get("autorizacao", "")) != "Bearer chave-resiliencia":
			continue
		if String(registro["caminho"]) != "/v1/sessoes/%s/eventos" % id_sessao:
			continue
		for evento: Dictionary in (registro["corpo"] as Dictionary).get("eventos", []):
			var id_evento: String = String(evento["id_evento"])
			if ids_de_evento.has(id_evento):
				duplicados += 1
			ids_de_evento[id_evento] = true

	afirmar_igual(duplicados, 0, "nenhum evento chegou duplicado ao eco")
	# SESSAO_INICIADA + 5 antes da queda + 5 durante a queda + SESSAO_ENCERRADA = 12
	afirmar_igual(ids_de_evento.size(), 12, "todos os eventos chegaram ao eco -- nenhum foi perdido")


func _drenar_o_que_der(tentativas: int) -> void:
	for i: int in tentativas:
		await Telemetria.descarregar()
		if Telemetria.fila_vazia():
			return
		await get_tree().process_frame
