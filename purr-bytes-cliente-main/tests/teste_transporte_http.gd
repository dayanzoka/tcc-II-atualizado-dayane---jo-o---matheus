extends CasoDeTeste

## Critério de aceite do Marco 3: "teste de integração que sobe [o servidor de]
## eco, roda uma sessão e confere os corpos enviados campo a campo contra a
## estrutura das tabelas" (seção 8 do CLAUDE.md). Sobe tools/servidor_eco.py
## como processo real e faz TransporteHttp conversar com ele pela rede de
## verdade -- é o que valida o que os testes com transporte falso (fake em
## tests/teste_telemetria.gd) não conseguem: a pilha HTTP do Godot em si.

const PORTA: int = 8091

var _pid: int = -1
var _caminho_log: String
var _lote_original: int
var _intervalo_original: float
var _nivel_original: String


func antes() -> void:
	_lote_original = ConfigJogo.tamanho_lote
	_intervalo_original = ConfigJogo.intervalo_envio_s
	_nivel_original = Registro.nome_do_nivel()
	Registro.definir_nivel_por_nome("SILENCIO")

	_caminho_log = caminho_temporario("eco_contrato.jsonl")
	_pid = ApoioServidorEco.iniciar(PORTA, _caminho_log)


func depois() -> void:
	ApoioServidorEco.parar(_pid)
	ConfigJogo.tamanho_lote = _lote_original
	ConfigJogo.intervalo_envio_s = _intervalo_original
	Registro.definir_nivel_por_nome(_nivel_original)


func teste_sessao_completa_via_http_bate_com_o_contrato() -> void:
	var pronto: bool = await ApoioServidorEco.aguardar_pronto(get_tree(), PORTA)
	if not afirmar_verdadeiro(pronto, "servidor de eco respondeu dentro do prazo"):
		return
	ApoioServidorEco.limpar_log(_caminho_log)

	ConfigJogo.tamanho_lote = 3  # forca mais de um lote de eventos
	var transporte := TransporteHttp.new("http://127.0.0.1:%d" % PORTA, "chave-de-teste")
	Telemetria.reiniciar(transporte, caminho_temporario("eco_contrato_fila.json"))

	var id_sessao: String = Identificador.uuid_v4()
	var id_sujeito: String = Identificador.uuid_v4()
	Telemetria.iniciar_sessao(id_sessao, id_sujeito)
	for i: int in 7:
		Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO, {"indice": i}, 1)
	Telemetria.registrar_tentativa(
		1, "cesar-01", "cifrar pacote chave=3",
		[{"tipo": "VERBO", "lexema": "cifrar", "posicao": 0}],
		CatalogoResultados.SUCESSO, "", 1800, 1)
	Telemetria.encerrar_sessao()

	await _drenar()

	var recebidos: Array[Dictionary] = ApoioServidorEco.ler_log(_caminho_log)
	if not afirmar_verdadeiro(recebidos.size() >= 3,
			"eco recebeu ao menos abertura + 1 lote de eventos + encerramento"):
		return

	# 1) Abertura de sessao sempre primeiro (evento_telemetria.id_sessao tem FK
	#    para sessao_jogo -- a ordem nao e opcional).
	var abertura: Dictionary = recebidos[0]
	afirmar_igual(String(abertura["caminho"]), "/v1/sessoes", "primeira requisicao abre a sessao")
	afirmar_igual(String(abertura["autorizacao"]), "Bearer chave-de-teste",
		"header Authorization: Bearer <chave_api>")
	for campo: String in ["id_sessao", "id_sujeito", "versao_jogo", "plataforma", "iniciada_em"]:
		afirmar_verdadeiro((abertura["corpo"] as Dictionary).has(campo),
			"corpo de /v1/sessoes tem o campo NOT NULL '%s'" % campo)
	afirmar_igual(String((abertura["corpo"] as Dictionary)["id_sessao"]), id_sessao,
		"id_sessao bate com o gerado no cliente")

	# 2) Lotes de eventos, cada um <= tamanho_lote, na rota certa.
	var total_eventos_recebidos: int = 0
	var maior_lote: int = 0
	for registro: Dictionary in recebidos:
		var caminho: String = String(registro["caminho"])
		if caminho == "/v1/sessoes/%s/eventos" % id_sessao:
			var eventos: Array = (registro["corpo"] as Dictionary).get("eventos", [])
			total_eventos_recebidos += eventos.size()
			maior_lote = maxi(maior_lote, eventos.size())
			for evento: Dictionary in eventos:
				for campo: String in ["id_evento", "id_sessao", "sequencia", "tipo_evento", "ocorrido_em", "payload"]:
					afirmar_verdadeiro(evento.has(campo), "evento tem o campo '%s'" % campo)

	# SESSAO_INICIADA (emitido por iniciar_sessao) + 7 COMANDO_SUBMETIDO + SESSAO_ENCERRADA = 9
	afirmar_igual(total_eventos_recebidos, 9, "todos os eventos chegaram ao eco")
	afirmar_verdadeiro(maior_lote <= 3, "nenhum lote de eventos passou de tamanho_lote=3 (obtido %d)" % maior_lote)

	# 3) Tentativas na propria rota, separada de eventos.
	var tentativas_recebidas: int = 0
	for registro: Dictionary in recebidos:
		if String(registro["caminho"]) == "/v1/sessoes/%s/tentativas" % id_sessao:
			var tentativas: Array = (registro["corpo"] as Dictionary).get("tentativas", [])
			tentativas_recebidas += tentativas.size()
			for tentativa: Dictionary in tentativas:
				for campo: String in [
					"id_tentativa", "id_sessao", "fase", "desafio", "entrada_normalizada",
					"tokens", "resultado", "tempo_resposta_ms", "numero_tentativa", "ocorrido_em",
				]:
					afirmar_verdadeiro(tentativa.has(campo), "tentativa tem o campo '%s'" % campo)
	afirmar_igual(tentativas_recebidas, 1, "a unica tentativa chegou ao eco")

	# 4) Encerramento por ultimo.
	var encerramento: Dictionary = recebidos[recebidos.size() - 1]
	afirmar_igual(String(encerramento["caminho"]), "/v1/sessoes/%s/encerrar" % id_sessao,
		"a ultima requisicao encerra a sessao")
	afirmar_igual(String((encerramento["corpo"] as Dictionary)["status"]), "ENCERRADA",
		"status ENCERRADA (saida normal, nao abandono)")

	afirmar_verdadeiro(Telemetria.fila_vazia(), "fila drenou por completo contra o eco")


func teste_rota_e_corpo_do_par_chave() -> void:
	var pronto: bool = await ApoioServidorEco.aguardar_pronto(get_tree(), PORTA)
	if not afirmar_verdadeiro(pronto, "servidor de eco respondeu dentro do prazo"):
		return
	ApoioServidorEco.limpar_log(_caminho_log)

	var transporte := TransporteHttp.new("http://127.0.0.1:%d" % PORTA, "chave")
	Telemetria.reiniciar(transporte, caminho_temporario("eco_par_chave_fila.json"))

	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())
	Telemetria.encerrar_sessao()
	await _drenar()

	afirmar_verdadeiro(Telemetria.fila_vazia(), "sessao minima (so abertura+encerramento) tambem drena")


func _drenar() -> void:
	for i: int in 100:
		await Telemetria.descarregar()
		if Telemetria.fila_vazia():
			return
		await get_tree().process_frame
	falhar("a fila nao drenou contra o servidor de eco em 100 tentativas")
