extends CasoDeTeste

## Criterios de aceite do Marco 0 que dependem da telemetria:
##   - sessao MOCK produz .jsonl com SESSAO_INICIADA e SESSAO_ENCERRADA,
##     sequencia 0 e 1 e o mesmo id_sessao
##   - fila cheia + processo morto + reabertura = fila recuperada do disco
##
## Mais o que a secao 4 exige e ninguem ve olhando a tela: truncamento do texto
## livre, sequencia sem lacuna, e nenhum codigo fora do catalogo saindo daqui.
##
## Nada aqui toca user://fila_telemetria.json nem o .jsonl reais: reiniciar()
## aponta o autoload para user://testes a cada teste.


## Transporte que sempre falha, para exercitar os dois destinos possiveis de um
## lote: preservado (transitorio) ou descartado (permanente).
class TransporteQueFalha extends TransporteTelemetria:
	var permanente: bool = false
	var tentativas: int = 0

	func _init(permanente_: bool) -> void:
		permanente = permanente_

	func rotulo() -> String:
		return "FALHA(%s)" % ("permanente" if permanente else "transitoria")

	func enviar(_pacote: Dictionary) -> ResultadoEnvio:
		await _ceder_quadro()
		tentativas += 1
		return ResultadoEnvio.falha_permanente("recusado no teste") if permanente \
			else ResultadoEnvio.falha_transitoria("rede fora no teste")


## Registra o tamanho de cada lote para provar que o teto e respeitado.
class TransporteEspiao extends TransporteTelemetria:
	var tamanhos: Array[int] = []
	var rotas: Array[String] = []

	func rotulo() -> String:
		return "ESPIAO"

	func enviar(pacote: Dictionary) -> ResultadoEnvio:
		await _ceder_quadro()
		rotas.append(String(pacote["rota"]))
		var quantidade: int = 1
		if pacote.has("eventos"):
			quantidade = (pacote["eventos"] as Array).size()
		elif pacote.has("tentativas"):
			quantidade = (pacote["tentativas"] as Array).size()
		tamanhos.append(quantidade)
		return ResultadoEnvio.ok()


var _lote_original: int
var _intervalo_original: float
var _nivel_original: String


func antes() -> void:
	_lote_original = ConfigJogo.tamanho_lote
	_intervalo_original = ConfigJogo.intervalo_envio_s
	_nivel_original = Registro.nome_do_nivel()
	# Lote grande e intervalo longo: sem descarga automatica no meio de um
	# teste, cada arquivo controla quando a fila drena.
	ConfigJogo.tamanho_lote = 500
	ConfigJogo.intervalo_envio_s = 3600.0
	# Varios testes daqui exercitam de proposito os caminhos que gritam (codigo
	# fora do catalogo, lote recusado). Sem silenciar, a saida de uma suite
	# verde fica cheia de push_error de erro esperado, e a suite deixa de servir
	# como sinal claro.
	Registro.definir_nivel_por_nome("SILENCIO")


func depois() -> void:
	ConfigJogo.tamanho_lote = _lote_original
	ConfigJogo.intervalo_envio_s = _intervalo_original
	Registro.definir_nivel_por_nome(_nivel_original)


# ---------------------------------------------------------------------------
# Criterios de aceite
# ---------------------------------------------------------------------------

func teste_sessao_mock_completa() -> void:
	var mock: TransporteMock = _preparar_mock("sessao")
	var id_sessao: String = Identificador.uuid_v4()
	var id_sujeito: String = Identificador.uuid_v4()

	Telemetria.iniciar_sessao(id_sessao, id_sujeito)
	Telemetria.encerrar_sessao()
	await _drenar()

	var registros: Array[Dictionary] = _ler_jsonl(mock.caminho())
	var eventos: Array[Dictionary] = _filtrar(registros, "evento")
	var sessoes: Array[Dictionary] = _filtrar(registros, "sessao")

	afirmar_tamanho(eventos, 2, "dois eventos de ciclo de vida no arquivo")
	afirmar_igual(eventos[0]["tipo_evento"], CatalogoEventos.SESSAO_INICIADA,
		"primeiro evento e SESSAO_INICIADA")
	afirmar_igual(eventos[1]["tipo_evento"], CatalogoEventos.SESSAO_ENCERRADA,
		"segundo evento e SESSAO_ENCERRADA")
	afirmar_igual(int(eventos[0]["sequencia"]), 0, "sequencia comeca em 0")
	afirmar_igual(int(eventos[1]["sequencia"]), 1, "sequencia segue em 1")
	afirmar_igual(String(eventos[0]["id_sessao"]), id_sessao, "id_sessao do primeiro evento")
	afirmar_igual(String(eventos[1]["id_sessao"]), id_sessao, "id_sessao identico no segundo")

	afirmar_tamanho(sessoes, 2, "abertura e encerramento da sessao registrados")
	afirmar_igual(String(registros[0]["rota"]), TransporteTelemetria.ROTA_ABRIR_SESSAO,
		"a abertura sai antes de qualquer evento (o banco tem FK para a sessao)")
	afirmar_igual(String(registros[registros.size() - 1]["rota"]),
		TransporteTelemetria.ROTA_ENCERRAR_SESSAO,
		"o encerramento sai por ultimo")

	var abertura: Dictionary = sessoes[0]
	for campo: String in ["id_sessao", "id_sujeito", "versao_jogo", "plataforma", "iniciada_em"]:
		afirmar_verdadeiro(abertura.has(campo),
			"corpo de POST /v1/sessoes tem o campo NOT NULL '%s'" % campo)
	afirmar_verdadeiro(String(abertura["iniciada_em"]).ends_with("Z"),
		"iniciada_em em UTC explicito")


func teste_fila_sobrevive_ao_processo_morto() -> void:
	var caminho_fila: String = caminho_temporario("fila_reinicio.json")
	var id_sessao: String = Identificador.uuid_v4()

	# 1. Sessao em andamento com a rede fora: nada sai, tudo fica na fila.
	Telemetria.reiniciar(TransporteQueFalha.new(false), caminho_fila)
	Telemetria.iniciar_sessao(id_sessao, Identificador.uuid_v4())
	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {"fase": 1}, 1)
	Telemetria.registrar_tentativa(1, "cesar-01", "cifrar pacote chave=3",
		[{"tipo": "VERBO", "lexema": "cifrar", "posicao": 0}],
		CatalogoResultados.SUCESSO, "", 1200, 1)
	await Telemetria.descarregar()

	var antes_do_reinicio: Dictionary = Telemetria.estatisticas()
	# SESSAO_INICIADA e FASE_INICIADA. A tentativa vai em fila propria, porque
	# tentativa_comando e tabela separada de evento_telemetria.
	afirmar_igual(int(antes_do_reinicio["eventos_na_fila"]), 2, "eventos presos na fila")
	afirmar_igual(int(antes_do_reinicio["tentativas_na_fila"]), 1, "tentativa presa na fila")
	afirmar_verdadeiro(bool(antes_do_reinicio["abertura_pendente"]),
		"a abertura da sessao tambem ficou pendente")
	afirmar_verdadeiro(FileAccess.file_exists(caminho_fila), "fila persistida em disco")

	# 2. Processo morto e reaberto: memoria zerada, disco intacto.
	var mock: TransporteMock = TransporteMock.new(caminho_temporario("mock_reinicio.jsonl"))
	Telemetria.reiniciar(mock, caminho_fila)
	afirmar_verdadeiro(Telemetria.fila_vazia(), "memoria realmente zerada antes de recuperar")

	Telemetria.recuperar_fila()
	var apos: Dictionary = Telemetria.estatisticas()
	afirmar_igual(int(apos["tentativas_na_fila"]), 1, "tentativa recuperada do disco")
	afirmar_verdadeiro(int(apos["eventos_na_fila"]) >= 2, "eventos recuperados do disco")

	# 3. Rede de volta: a fila drena inteira, com os IDs originais.
	await _drenar()
	var registros: Array[Dictionary] = _ler_jsonl(mock.caminho())
	var eventos: Array[Dictionary] = _filtrar(registros, "evento")
	var tentativas: Array[Dictionary] = _filtrar(registros, "tentativa")

	afirmar_tamanho(tentativas, 1, "a tentativa chegou ao destino")
	afirmar_igual(String(eventos[0]["id_sessao"]), id_sessao,
		"os eventos recuperados mantem o id_sessao da execucao anterior")
	_afirmar_sequencia_sem_lacuna(eventos)

	# Sessao que ficou aberta vira SESSAO_ABANDONADA: distingue, na analise,
	# quem desistiu de quem teve o processo encerrado por acidente.
	var tipos: PackedStringArray = _tipos(eventos)
	afirmar_verdadeiro(tipos.has(CatalogoEventos.SESSAO_ABANDONADA),
		"sessao interrompida e marcada como abandonada na reabertura")
	afirmar_igual(_contar(tipos, CatalogoEventos.FASE_INICIADA), 1,
		"nenhum evento duplicado apos a recuperacao")


# ---------------------------------------------------------------------------
# Sequencia e catalogo
# ---------------------------------------------------------------------------

func teste_sequencia_monotonica_sem_lacuna() -> void:
	var mock: TransporteMock = _preparar_mock("sequencia")
	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())
	for i: int in 60:
		Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO, {"indice": i}, 1)
	Telemetria.encerrar_sessao()
	await _drenar()

	var eventos: Array[Dictionary] = _filtrar(_ler_jsonl(mock.caminho()), "evento")
	afirmar_tamanho(eventos, 62, "60 comandos + inicio + encerramento")
	_afirmar_sequencia_sem_lacuna(eventos)


func teste_evento_fora_do_catalogo_nao_consome_sequencia() -> void:
	var mock: TransporteMock = _preparar_mock("catalogo")
	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())

	var recusado: Dictionary = Telemetria.registrar_evento("CACHORRO_LATIU", {})
	afirmar_tamanho(recusado, 0, "codigo fora do catalogo nao vira evento")

	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {}, 1)
	await _drenar()

	var eventos: Array[Dictionary] = _filtrar(_ler_jsonl(mock.caminho()), "evento")
	# Descartar o evento invalido nao pode abrir buraco na sequencia: buraco e
	# lido como perda de pacote na analise.
	_afirmar_sequencia_sem_lacuna(eventos)
	afirmar_igual(int(eventos[1]["sequencia"]), 1,
		"o evento seguinte ao recusado continua a numeracao sem pular")


func teste_evento_sem_sessao_e_descartado() -> void:
	_preparar_mock("sem_sessao")
	var evento: Dictionary = Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {}, 1)
	afirmar_tamanho(evento, 0,
		"evento sem sessao aberta e descartado (id_sessao e NOT NULL com FK)")


func teste_fase_fora_da_faixa_vira_nulo() -> void:
	_preparar_mock("fase")
	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())

	var fora: Dictionary = Telemetria.registrar_evento(CatalogoEventos.DICA_SOLICITADA, {}, 0)
	afirmar_nulo(fora["fase"], "fase 0 viaja como null (CHECK fase BETWEEN 1 AND 4)")

	var dentro: Dictionary = Telemetria.registrar_evento(CatalogoEventos.DICA_SOLICITADA, {}, 3)
	afirmar_igual(int(dentro["fase"]), 3, "fase valida e preservada")


# ---------------------------------------------------------------------------
# Privacidade (restricoes 1 e 2 da secao 4)
# ---------------------------------------------------------------------------

func teste_texto_livre_truncado_em_240() -> void:
	_preparar_mock("truncamento")
	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())

	var entrada: String = "cifrar " + "a".repeat(500)
	var tentativa: Dictionary = Telemetria.registrar_tentativa(
		1, "identificador-de-desafio-propositalmente-muito-longo-para-estourar-o-limite",
		entrada,
		[{"tipo": "IDENTIFICADOR", "lexema": "b".repeat(200), "posicao": 7}],
		CatalogoResultados.ERRO_SEMANTICO, "c".repeat(80), -50, 0)

	afirmar_igual(String(tentativa["entrada_normalizada"]).length(), 240,
		"entrada_normalizada truncada em 240 (VARCHAR(240) e limite-texto-livre)")
	afirmar_verdadeiro(String(tentativa["desafio"]).length() <= 60,
		"desafio cabe em VARCHAR(60)")
	afirmar_verdadeiro(String(tentativa["codigo_erro"]).length() <= 40,
		"codigo_erro cabe em VARCHAR(40)")
	afirmar_igual(int(tentativa["tempo_resposta_ms"]), 0,
		"tempo negativo vira 0 (ck_tentativa_tempo)")
	afirmar_igual(int(tentativa["numero_tentativa"]), 1,
		"numero_tentativa comeca em 1 (ck_tentativa_numero)")


func teste_sanitizacao_de_controle_e_espaco() -> void:
	_preparar_mock("sanitizacao")
	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())

	var tentativa: Dictionary = Telemetria.registrar_tentativa(
		2, "vigenere-01", "  cifrar\tpacote\n\nchave=gato  ", [],
		CatalogoResultados.SUCESSO, "", 900, 2)

	afirmar_igual(String(tentativa["entrada_normalizada"]), "cifrar pacote chave=gato",
		"tabulacao, quebra de linha e espaco repetido colapsam em um espaco")
	afirmar_nulo(tentativa["codigo_erro"], "codigo_erro e null em caso de sucesso")


func teste_payload_e_sanitizado_em_profundidade() -> void:
	_preparar_mock("payload")
	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())

	var evento: Dictionary = Telemetria.registrar_evento(CatalogoEventos.CACHORRO_DETECTOU, {
		"posicao": Vector2(3, 4),
		"detalhe": {"comando": "x".repeat(400)},
		"lista": ["y".repeat(300)],
	}, 1)

	var payload: Dictionary = evento["payload"] as Dictionary
	afirmar_igual(payload["posicao"], {"x": 3.0, "y": 4.0},
		"Vector2 vira objeto JSON em vez de virar a string '(3, 4)'")
	afirmar_igual(String((payload["detalhe"] as Dictionary)["comando"]).length(), 240,
		"texto aninhado tambem e truncado")
	afirmar_igual(String((payload["lista"] as Array)[0]).length(), 240,
		"texto dentro de lista tambem e truncado")


func teste_tentativa_com_resultado_invalido_e_recusada() -> void:
	_preparar_mock("resultado")
	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())
	var t: Dictionary = Telemetria.registrar_tentativa(
		1, "cesar-01", "cifrar pacote chave=3", [], "QUASE_CERTO", "", 100, 1)
	afirmar_tamanho(t, 0, "resultado fora da constraint nao vira registro")


# ---------------------------------------------------------------------------
# Lote e resiliencia
# ---------------------------------------------------------------------------

func teste_lote_respeita_o_tamanho_configurado() -> void:
	var espiao := TransporteEspiao.new()
	Telemetria.reiniciar(espiao, caminho_temporario("fila_lote.json"))
	ConfigJogo.tamanho_lote = 10

	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())
	for i: int in 25:
		Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO, {"indice": i}, 1)
	await _drenar()

	afirmar_verdadeiro(espiao.tamanhos.size() >= 3, "os eventos sairam em varios lotes")
	for tamanho: int in espiao.tamanhos:
		afirmar_verdadeiro(tamanho <= 10, "nenhum lote passou de 10 (obtido %d)" % tamanho)
		afirmar_verdadeiro(tamanho <= Telemetria.TETO_EVENTOS_POR_LOTE,
			"nenhum lote passou do teto do back-end")
	afirmar_igual(espiao.rotas[0], TransporteTelemetria.ROTA_ABRIR_SESSAO,
		"a sessao e aberta antes do primeiro lote de eventos")


func teste_falha_transitoria_preserva_a_fila() -> void:
	var falho := TransporteQueFalha.new(false)
	Telemetria.reiniciar(falho, caminho_temporario("fila_transitoria.json"))
	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())
	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {}, 1)

	await Telemetria.descarregar()

	afirmar_falso(Telemetria.fila_vazia(), "5xx e queda de rede nao descartam dado")
	afirmar_igual(int(Telemetria.estatisticas()["falhas_consecutivas"]), 1,
		"a falha e contada para o backoff")
	afirmar_igual(int(Telemetria.estatisticas()["itens_descartados"]), 0,
		"nada foi perdido")


func teste_falha_permanente_descarta_o_lote() -> void:
	var falho := TransporteQueFalha.new(true)
	Telemetria.reiniciar(falho, caminho_temporario("fila_permanente.json"))
	Telemetria.iniciar_sessao(Identificador.uuid_v4(), Identificador.uuid_v4())
	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {}, 1)

	await Telemetria.descarregar()

	# 4xx significa lote malformado: insistir daria o mesmo erro para sempre.
	afirmar_verdadeiro(Telemetria.fila_vazia(), "o lote recusado sai da fila")
	afirmar_verdadeiro(int(Telemetria.estatisticas()["itens_descartados"]) > 0,
		"o descarte e contabilizado, e nao silencioso")


func teste_rotas_do_contrato_rest() -> void:
	var http := TransporteHttp.new("http://localhost:8080", "chave")
	var id: String = "11111111-2222-4333-8444-555555555555"
	afirmar_igual(http.caminho_da_rota(TransporteTelemetria.ROTA_ABRIR_SESSAO, id),
		"/v1/sessoes", "rota de abertura")
	afirmar_igual(http.caminho_da_rota(TransporteTelemetria.ROTA_EVENTOS, id),
		"/v1/sessoes/%s/eventos" % id, "rota de eventos")
	afirmar_igual(http.caminho_da_rota(TransporteTelemetria.ROTA_TENTATIVAS, id),
		"/v1/sessoes/%s/tentativas" % id, "rota de tentativas")
	afirmar_igual(http.caminho_da_rota(TransporteTelemetria.ROTA_ENCERRAR_SESSAO, id),
		"/v1/sessoes/%s/encerrar" % id, "rota de encerramento")
	afirmar_verdadeiro(TransporteHttp.disponivel(),
		"o transporte HTTP esta disponivel a partir do Marco 3")
	http.free()


# ---------------------------------------------------------------------------
# Apoio
# ---------------------------------------------------------------------------

func _preparar_mock(sufixo: String) -> TransporteMock:
	var mock := TransporteMock.new(caminho_temporario("mock_%s.jsonl" % sufixo))
	Telemetria.reiniciar(mock, caminho_temporario("fila_%s.json" % sufixo))
	return mock


## Drena ate a fila esvaziar, com teto de iteracoes para um transporte quebrado
## nao pendurar a suite.
func _drenar() -> void:
	for i: int in 50:
		await Telemetria.descarregar()
		if Telemetria.fila_vazia():
			return
		await get_tree().process_frame
	falhar("a fila nao drenou em 50 tentativas")


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
			falhar("linha do .jsonl nao e um objeto JSON: %s" % linha)
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


func _contar(lista: PackedStringArray, alvo: String) -> int:
	var total: int = 0
	for item: String in lista:
		if item == alvo:
			total += 1
	return total


## Restricao 5: monotonica, comecando em 0, sem lacuna. E o que permite ao
## back-end detectar perda de pacote -- se o cliente furar isso, a deteccao
## passa a acusar perda onde nao houve.
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
