extends Node

## Autoload Telemetria -- fila, lote, persistencia e retentativa.
##
## Este arquivo carrega a restricao 6 da secao 4 do CLAUDE.md nas costas: o jogo
## nunca trava por causa do servidor. Nada aqui bloqueia; todo envio e corrotina
## que cede um quadro antes de tocar em disco ou rede, e a fila sobrevive ao
## processo em user://fila_telemetria.json.
##
## Divisao de responsabilidade com o transporte (scripts/telemetria/):
##   aqui       -- sequencia, sanitizacao, lote, persistencia, backoff
##   transporte -- como os bytes saem (MOCK em disco, HTTP no Marco 3)
##
## Desvio consciente do organograma do CLAUDE.md: o contador de sequencia mora
## aqui, e nao em Sessao. Motivo: a sequencia tem que ser monotonica e sem
## lacuna (restricao 5), e a garantia mais simples disso e um unico escritor.
## Todo evento passa por registrar_evento(), entao aqui e o unico ponto do
## codigo capaz de furar a regra -- e o unico que precisa ser auditado.

signal evento_registrado(evento: Dictionary)
signal tentativa_registrada(tentativa: Dictionary)
signal lote_confirmado(rota: String, quantidade: int)
signal falha_de_envio(rota: String, detalhe: String, permanente: bool)

const CAMINHO_FILA_PADRAO: String = "user://fila_telemetria.json"

## Copia local do que o modo HTTP ja entregou, ao lado do arquivo de fila. Em
## MOCK o proprio arquivo do transporte ja e esse registro.
const NOME_HISTORICO_LOCAL: String = "historico_telemetria.jsonl"
const VERSAO_FILA: int = 1

## Limites copiados do schema do back-end. Truncar aqui, e nao la, e o que
## cumpre a restricao 2 da secao 4: o texto reduzido e o unico que sai do
## cliente. O arquivo do modo MOCK tambem fica conforme, e por isso serve como
## evidencia de conformidade na monografia.
const LIMITE_TEXTO_LIVRE: int = 240  # tentativa_comando.entrada_normalizada VARCHAR(240)
const LIMITE_DESAFIO: int = 60       # tentativa_comando.desafio VARCHAR(60)
const LIMITE_CODIGO_ERRO: int = 40   # tentativa_comando.codigo_erro VARCHAR(40)
const LIMITE_LEXEMA: int = 60
const PROFUNDIDADE_MAXIMA_PAYLOAD: int = 4

## Teto do back-end (purrbytes.ingestao.max-eventos-por-lote, padrao 500).
## Lote acima disso volta 4xx, o que significa lote inteiro descartado.
const TETO_EVENTOS_POR_LOTE: int = 500

## Ultima linha de defesa contra memoria: se a API ficar fora por horas, a fila
## para de crescer e comeca a descartar o mais antigo, sempre com log de erro.
## Preferir perder o inicio a derrubar o jogo no meio da coleta.
const MAX_ITENS_EM_FILA: int = 20000

const TETO_BACKOFF_S: float = 60.0

const STATUS_ENCERRADA: String = "ENCERRADA"
const STATUS_ABANDONADA: String = "ABANDONADA"

var _transporte: TransporteTelemetria = null

## So existe fora do modo MOCK. Sem ele, o painel de fases jogadas ficaria vazio
## justamente na coleta real (HTTP): o professor nao veria o que a propria
## maquina ja enviou. Grava o MESMO pacote, no mesmo formato do MOCK, e so
## depois do 2xx -- o que esta no historico e o que o servidor aceitou.
var _historico_local: TransporteMock = null
var _caminho_fila: String = CAMINHO_FILA_PADRAO

var _eventos: Array[Dictionary] = []
var _tentativas: Array[Dictionary] = []
var _abertura_pendente: Dictionary = {}
var _encerramento_pendente: Dictionary = {}

var _id_sessao: String = ""
var _sequencia: int = 0
var _sessao_aberta: bool = false

var _descarregando: bool = false
var _falhas_consecutivas: int = 0
var _temporizador: Timer = null

var _eventos_descartados: int = 0


func _ready() -> void:
	# A telemetria continua enfileirando e drenando com o jogo pausado: uma
	# pausa no menu no meio de uma retentativa nao pode segurar a fila.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_temporizador = Timer.new()
	_temporizador.name = "TemporizadorDeDescarga"
	_temporizador.wait_time = maxf(0.5, ConfigJogo.intervalo_envio_s)
	_temporizador.autostart = true
	_temporizador.timeout.connect(_ao_vencer_temporizador)
	add_child(_temporizador)

	_selecionar_transporte()
	recuperar_fila()


func _notification(que: int) -> void:
	# Fechar a janela e o caso comum de fim de sessao. Persistir aqui e o que
	# transforma "o jogador fechou o jogo" em dado recuperavel no proximo boot.
	if que == NOTIFICATION_WM_CLOSE_REQUEST \
			or que == NOTIFICATION_APPLICATION_PAUSED \
			or que == NOTIFICATION_EXIT_TREE:
		_persistir()


# ---------------------------------------------------------------------------
# API publica
# ---------------------------------------------------------------------------

## Ponto de injecao para os testes: troca o transporte e o arquivo de fila por
## um par temporario. Em runtime quem chama e _selecionar_transporte().
func configurar(transporte: TransporteTelemetria, caminho_fila: String) -> void:
	if _transporte != null and _transporte.get_parent() == self:
		_transporte.queue_free()
	_transporte = transporte
	add_child(_transporte)
	_caminho_fila = caminho_fila

	if _historico_local != null:
		_historico_local.queue_free()
		_historico_local = null
	if not (_transporte is TransporteMock):
		# Deriva da pasta da fila para os testes (fila temporaria) nunca
		# escreverem no historico real do jogador.
		_historico_local = TransporteMock.new(
			_caminho_fila.get_base_dir().path_join(NOME_HISTORICO_LOCAL))
		_historico_local.name = "HistoricoLocal"
		add_child(_historico_local)
	Registro.info("Telemetria", "transporte: %s | fila: %s" % [_transporte.rotulo(), _caminho_fila])


## Zera o estado em memoria e troca transporte e arquivo de fila, sem apagar o
## que ja esta no disco. E assim que os testes simulam "processo morto e
## reaberto" sem precisar de um segundo processo: reiniciar() esquece tudo,
## recuperar_fila() le de volta -- exatamente a sequencia que acontece num boot.
func reiniciar(transporte: TransporteTelemetria, caminho_fila: String) -> void:
	_eventos.clear()
	_tentativas.clear()
	_abertura_pendente = {}
	_encerramento_pendente = {}
	_id_sessao = ""
	_sequencia = 0
	_sessao_aberta = false
	_falhas_consecutivas = 0
	_eventos_descartados = 0
	_descarregando = false
	configurar(transporte, caminho_fila)


func iniciar_sessao(id_sessao: String, id_sujeito: String) -> void:
	if not Identificador.e_uuid(id_sessao):
		Registro.erro("Telemetria", "id_sessao fora do formato UUID; sessao nao iniciada")
		return

	if _sessao_aberta:
		# Duas sessoes abertas ao mesmo tempo tornariam a sequencia ambigua.
		Registro.aviso("Telemetria",
			"iniciar_sessao com sessao ainda aberta; encerrando a anterior como ABANDONADA")
		encerrar_sessao(STATUS_ABANDONADA)

	_id_sessao = id_sessao
	_sequencia = 0
	_sessao_aberta = true
	_encerramento_pendente = {}

	# Corpo de POST /v1/sessoes. Os campos sao exatamente as colunas NOT NULL de
	# pesquisa.sessao_jogo (V2__pesquisa.sql), nada alem disso.
	_abertura_pendente = {
		"id_sessao": _id_sessao,
		"id_sujeito": id_sujeito,
		"versao_jogo": ConfigJogo.versao_jogo,
		"plataforma": ConfigJogo.plataforma,
		"iniciada_em": Relogio.agora_utc_iso(),
	}

	registrar_evento(CatalogoEventos.SESSAO_INICIADA, {
		"modo_telemetria": ConfigJogo.modo_telemetria,
	})
	_persistir()


func encerrar_sessao(status: String = STATUS_ENCERRADA) -> void:
	if not _sessao_aberta:
		Registro.aviso("Telemetria", "encerrar_sessao sem sessao aberta; ignorado")
		return

	var codigo: String = CatalogoEventos.SESSAO_ENCERRADA
	if status == STATUS_ABANDONADA:
		codigo = CatalogoEventos.SESSAO_ABANDONADA
	registrar_evento(codigo, {"status": status})

	# Corpo de POST /v1/sessoes/{id}/encerrar.
	_encerramento_pendente = {
		"id_sessao": _id_sessao,
		"status": status,
		"encerrada_em": Relogio.agora_utc_iso(),
	}
	_sessao_aberta = false
	_persistir()


## A fase de um evento e identificada por `id_fase` (UUID), nao pelo numero.
##
## O numero existia porque o banco nasceu com quatro fases fixas
## (CHECK fase BETWEEN 1 AND 4). Com fases criadas livremente esse numero deixa
## de ser identidade, e amarrar a coleta a ele significava PERDER a telemetria
## de toda fase fora da faixa -- que e o oposto do que a instrumentacao existe
## para fazer.
##
## Entao: `id_fase` e `titulo_fase` vem de Sessao e viajam em todo evento, e
## nenhum evento e descartado por causa de numero de fase. O campo numerico
## `fase` continua sendo enviado como LEGADO, e vai null fora de 1..4 -- nao por
## amarra do cliente, mas porque o CHECK ainda existe no banco de producao e um
## valor fora da faixa faria a API recusar o LOTE INTEIRO (4xx = erro
## permanente = lote descartado), levando junto centenas de eventos validos. A
## identidade real esta em id_fase; no dia em que o CHECK cair, basta parar de
## anular aqui. Ver docs/contrato-telemetria.md.
func registrar_evento(tipo_evento: String, payload: Dictionary = {}, fase: int = 0) -> Dictionary:
	# Restricao 7: codigo fora do catalogo nao existe. Descartar aqui e melhor
	# que enviar: tipo_evento tem chave estrangeira para pesquisa.tipo_evento, e
	# um codigo invalido faria a API recusar o lote inteiro -- levando embora
	# centenas de eventos validos junto.
	if not CatalogoEventos.existe(tipo_evento):
		Registro.erro("Telemetria",
			"tipo de evento fora do catalogo, descartado: %s" % tipo_evento)
		return {}

	if not _sessao_aberta and tipo_evento != CatalogoEventos.SESSAO_ABANDONADA:
		# evento_telemetria.id_sessao e NOT NULL com FK: evento sem sessao nao
		# tem onde ser gravado.
		Registro.aviso("Telemetria",
			"evento %s sem sessao aberta, descartado" % tipo_evento)
		return {}

	var evento: Dictionary = {
		"id_evento": Identificador.uuid_v4(),
		"id_sessao": _id_sessao,
		"sequencia": _sequencia,
		"tipo_evento": tipo_evento,
		"id_fase": Sessao.id_fase,
		"titulo_fase": _sanitizar_texto(Sessao.titulo_fase, LIMITE_DESAFIO),
		"fase": fase if fase >= 1 and fase <= 4 else null,
		"ocorrido_em": Relogio.agora_utc_iso(),
		"payload": _sanitizar_payload(payload, 0),
	}
	_sequencia += 1

	_eventos.append(evento)
	_aplicar_teto_da_fila()
	evento_registrado.emit(evento)

	if _eventos.size() >= ConfigJogo.tamanho_lote:
		descarregar()

	return evento


## Uma linha de pesquisa.tentativa_comando. Tabela separada, e nao um payload de
## evento, porque e daqui que saem as tres metricas objetivas do Eixo 1 -- taxa
## de acerto, tempo de resposta e uso correto dos comandos.
func registrar_tentativa(
		fase: int,
		desafio: String,
		entrada_normalizada: String,
		tokens: Array[Dictionary],
		resultado: String,
		codigo_erro: String,
		tempo_resposta_ms: int,
		numero_tentativa: int) -> Dictionary:

	if not CatalogoResultados.existe(resultado):
		Registro.erro("Telemetria",
			"resultado fora da constraint ck_tentativa_resultado, descartado: %s" % resultado)
		return {}

	# A tentativa NAO e mais descartada por numero de fase: numa ferramenta de
	# fases livres, isso jogaria fora o dado da maioria das fases. A identidade
	# viaja em id_fase; ver o cabecalho de registrar_evento.

	if not _sessao_aberta:
		Registro.aviso("Telemetria", "tentativa sem sessao aberta, descartada")
		return {}

	var tentativa: Dictionary = {
		"id_tentativa": Identificador.uuid_v4(),
		"id_sessao": _id_sessao,
		"id_fase": Sessao.id_fase,
		"titulo_fase": _sanitizar_texto(Sessao.titulo_fase, LIMITE_DESAFIO),
		# Legado, pelo mesmo motivo do evento: o CHECK do banco ainda existe.
		"fase": fase if fase >= 1 and fase <= 4 else null,
		"desafio": _sanitizar_texto(desafio, LIMITE_DESAFIO),
		"entrada_normalizada": _sanitizar_texto(entrada_normalizada, LIMITE_TEXTO_LIVRE),
		"tokens": _sanitizar_tokens(tokens),
		"resultado": resultado,
		# codigo_erro e nulavel e deve ser null em caso de SUCESSO.
		"codigo_erro": null if codigo_erro.is_empty() \
			else _sanitizar_texto(codigo_erro, LIMITE_CODIGO_ERRO),
		"tempo_resposta_ms": maxi(0, tempo_resposta_ms),
		"numero_tentativa": maxi(1, numero_tentativa),
		"ocorrido_em": Relogio.agora_utc_iso(),
	}

	_tentativas.append(tentativa)
	_aplicar_teto_da_fila()
	tentativa_registrada.emit(tentativa)

	if _tentativas.size() >= ConfigJogo.tamanho_lote:
		descarregar()

	return tentativa


## Drena a fila. E corrotina: o temporizador chama sem await, os testes e o
## encerramento do jogo chamam com await para saber que terminou.
func descarregar() -> void:
	if _descarregando or _transporte == null:
		return
	_descarregando = true

	# Escrita adiantada: o disco passa a refletir o que ainda nao saiu ANTES da
	# primeira tentativa. Um processo morto no meio do envio perde no maximo os
	# eventos gerados desde o ultimo tique, nunca a fila inteira.
	_persistir()

	while true:
		var pacote: Dictionary = _proximo_pacote()
		if pacote.is_empty():
			break

		var resultado: ResultadoEnvio = await _transporte.enviar(pacote)
		var rota: String = String(pacote["rota"])

		if resultado.sucesso:
			var quantidade: int = _remover_do_pacote(pacote)
			_falhas_consecutivas = 0
			_temporizador.wait_time = maxf(0.5, ConfigJogo.intervalo_envio_s)
			if _historico_local != null:
				# Falha aqui nao volta o item para a fila: o servidor ja o tem,
				# reenviar duplicaria dado de pesquisa por causa de uma copia local.
				await _historico_local.enviar(pacote)
			lote_confirmado.emit(rota, quantidade)
		elif resultado.permanente:
			# 4xx: reenviar daria o mesmo erro para sempre. Descarta e grita --
			# este log e a unica pista de que houve perda de dado de pesquisa.
			var perdidos: int = _remover_do_pacote(pacote)
			_eventos_descartados += perdidos
			Registro.erro("Telemetria", "lote %s descartado por erro permanente (%d item(ns)): %s"
				% [rota, perdidos, resultado.detalhe])
			falha_de_envio.emit(rota, resultado.detalhe, true)
		else:
			_falhas_consecutivas += 1
			_agendar_retentativa()
			Registro.aviso("Telemetria", "falha transitoria em %s (tentativa %d): %s"
				% [rota, _falhas_consecutivas, resultado.detalhe])
			falha_de_envio.emit(rota, resultado.detalhe, false)
			break

	_persistir()
	_descarregando = false


## Caminho do registro local da coleta -- a fonte do Dashboard de Telemetria.
## Em MOCK e o arquivo do proprio transporte; em HTTP e a copia local do que o
## servidor ja aceitou (_historico_local). Vazio so sem transporte nenhum.
func caminho_do_registro_local() -> String:
	var mock := _transporte as TransporteMock
	if mock != null:
		return mock.caminho()
	return _historico_local.caminho() if _historico_local != null else ""


func estatisticas() -> Dictionary:
	return {
		"id_sessao": _id_sessao,
		"sessao_aberta": _sessao_aberta,
		"proxima_sequencia": _sequencia,
		"eventos_na_fila": _eventos.size(),
		"tentativas_na_fila": _tentativas.size(),
		"abertura_pendente": not _abertura_pendente.is_empty(),
		"encerramento_pendente": not _encerramento_pendente.is_empty(),
		"falhas_consecutivas": _falhas_consecutivas,
		"itens_descartados": _eventos_descartados,
		"transporte": "nenhum" if _transporte == null else _transporte.rotulo(),
	}


func fila_vazia() -> bool:
	return _eventos.is_empty() and _tentativas.is_empty() \
		and _abertura_pendente.is_empty() and _encerramento_pendente.is_empty()


# ---------------------------------------------------------------------------
# Lote e fila
# ---------------------------------------------------------------------------

## Ordem fixa e obrigatoria: a sessao tem que existir no banco antes dos eventos
## (FK), e o encerramento vai por ultimo para nao fechar a sessao antes de o
## ultimo evento chegar.
func _proximo_pacote() -> Dictionary:
	if not _abertura_pendente.is_empty():
		return {
			"rota": TransporteTelemetria.ROTA_ABRIR_SESSAO,
			"id_sessao": String(_abertura_pendente["id_sessao"]),
			"corpo": _abertura_pendente,
		}

	if not _eventos.is_empty():
		var limite: int = mini(mini(ConfigJogo.tamanho_lote, TETO_EVENTOS_POR_LOTE), _eventos.size())
		return {
			"rota": TransporteTelemetria.ROTA_EVENTOS,
			"id_sessao": String(_eventos[0]["id_sessao"]),
			"eventos": _eventos.slice(0, limite),
		}

	if not _tentativas.is_empty():
		var limite_t: int = mini(mini(ConfigJogo.tamanho_lote, TETO_EVENTOS_POR_LOTE), _tentativas.size())
		return {
			"rota": TransporteTelemetria.ROTA_TENTATIVAS,
			"id_sessao": String(_tentativas[0]["id_sessao"]),
			"tentativas": _tentativas.slice(0, limite_t),
		}

	if not _encerramento_pendente.is_empty():
		return {
			"rota": TransporteTelemetria.ROTA_ENCERRAR_SESSAO,
			"id_sessao": String(_encerramento_pendente["id_sessao"]),
			"corpo": _encerramento_pendente,
		}

	return {}


## Remove da fila os itens que o pacote levava. Seguro contra eventos novos
## enfileirados durante o await: o pacote sempre sai da frente da fila e novos
## itens entram no fim.
func _remover_do_pacote(pacote: Dictionary) -> int:
	match String(pacote["rota"]):
		TransporteTelemetria.ROTA_ABRIR_SESSAO:
			_abertura_pendente = {}
			return 1
		TransporteTelemetria.ROTA_EVENTOS:
			var n: int = (pacote["eventos"] as Array).size()
			_eventos = _eventos.slice(n)
			return n
		TransporteTelemetria.ROTA_TENTATIVAS:
			var m: int = (pacote["tentativas"] as Array).size()
			_tentativas = _tentativas.slice(m)
			return m
		TransporteTelemetria.ROTA_ENCERRAR_SESSAO:
			_encerramento_pendente = {}
			return 1
	return 0


func _aplicar_teto_da_fila() -> void:
	var excesso: int = _eventos.size() + _tentativas.size() - MAX_ITENS_EM_FILA
	if excesso <= 0:
		return
	# Descarta o mais antigo primeiro: em analise de aprendizado, o fim da
	# partida diz mais que o inicio.
	var remover_eventos: int = mini(excesso, _eventos.size())
	_eventos = _eventos.slice(remover_eventos)
	var restante: int = excesso - remover_eventos
	if restante > 0:
		_tentativas = _tentativas.slice(mini(restante, _tentativas.size()))
	_eventos_descartados += excesso
	Registro.erro("Telemetria",
		"fila estourou %d itens; %d registro(s) antigo(s) descartado(s)"
			% [MAX_ITENS_EM_FILA, excesso])


func _ao_vencer_temporizador() -> void:
	if fila_vazia():
		return
	descarregar()


## Backoff exponencial com jitter. O jitter existe para evitar que uma sala de
## aula inteira, que perdeu a rede no mesmo instante, volte a bater na API toda
## no mesmo milissegundo.
func _agendar_retentativa() -> void:
	var base: float = maxf(0.5, ConfigJogo.intervalo_envio_s)
	var espera: float = minf(base * pow(2.0, float(_falhas_consecutivas)), TETO_BACKOFF_S)
	var jitter: float = randf() * espera * 0.3
	_temporizador.wait_time = espera + jitter
	Registro.depuracao("Telemetria", "proxima tentativa em %.1fs" % _temporizador.wait_time)


# ---------------------------------------------------------------------------
# Persistencia
# ---------------------------------------------------------------------------

func _persistir() -> void:
	var dados: Dictionary = {
		"versao": VERSAO_FILA,
		"id_sessao": _id_sessao,
		"sequencia": _sequencia,
		"sessao_aberta": _sessao_aberta,
		"abertura_pendente": _abertura_pendente,
		"encerramento_pendente": _encerramento_pendente,
		"eventos": _eventos,
		"tentativas": _tentativas,
		"itens_descartados": _eventos_descartados,
	}

	# Grava em arquivo temporario e renomeia: um processo morto durante a
	# escrita deixaria um JSON truncado, e JSON truncado e fila inteira perdida.
	var temporario: String = _caminho_fila + ".tmp"
	var arquivo: FileAccess = FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		Registro.erro("Telemetria", "nao foi possivel escrever a fila em %s (erro %d)"
			% [temporario, FileAccess.get_open_error()])
		return
	arquivo.store_string(JSON.stringify(dados))
	arquivo.close()

	var erro: Error = DirAccess.rename_absolute(temporario, _caminho_fila)
	if erro != OK:
		Registro.erro("Telemetria", "falha ao trocar a fila persistida (erro %d)" % erro)


## Publica porque o boot nao e o unico momento em que faz sentido reler o disco:
## os testes a chamam para simular a reabertura do processo.
func recuperar_fila() -> void:
	if not FileAccess.file_exists(_caminho_fila):
		return

	var arquivo: FileAccess = FileAccess.open(_caminho_fila, FileAccess.READ)
	if arquivo == null:
		Registro.erro("Telemetria", "fila existe mas nao abriu (erro %d)"
			% FileAccess.get_open_error())
		return
	var bruto: String = arquivo.get_as_text()
	arquivo.close()

	var lido: Variant = JSON.parse_string(bruto)
	if lido == null or typeof(lido) != TYPE_DICTIONARY:
		Registro.erro("Telemetria", "fila persistida ilegivel; arquivo preservado como .corrompido")
		DirAccess.rename_absolute(_caminho_fila, _caminho_fila + ".corrompido")
		return

	var dados: Dictionary = lido as Dictionary
	if int(dados.get("versao", 0)) != VERSAO_FILA:
		Registro.aviso("Telemetria", "fila persistida em versao incompativel; ignorada")
		return

	_id_sessao = String(dados.get("id_sessao", ""))
	_sequencia = int(dados.get("sequencia", 0))
	_abertura_pendente = dados.get("abertura_pendente", {}) as Dictionary
	_encerramento_pendente = dados.get("encerramento_pendente", {}) as Dictionary
	_eventos_descartados = int(dados.get("itens_descartados", 0))
	_eventos = _converter_lista(dados.get("eventos", [] as Array))
	_tentativas = _converter_lista(dados.get("tentativas", [] as Array))
	_sessao_aberta = bool(dados.get("sessao_aberta", false))

	Registro.info("Telemetria", "fila recuperada: %d evento(s), %d tentativa(s)"
		% [_eventos.size(), _tentativas.size()])

	# Sessao que ficou aberta significa que o processo anterior morreu sem
	# encerrar -- travamento, queda de energia ou fim de aula. Registrar isso
	# como SESSAO_ABANDONADA distingue, na analise, quem desistiu de quem
	# perdeu o jogo por acidente. A sequencia continua de onde parou, sem
	# lacuna, porque ela foi persistida junto.
	if _sessao_aberta:
		Registro.aviso("Telemetria",
			"sessao %s ficou aberta na execucao anterior; marcada como ABANDONADA" % _id_sessao)
		_sessao_aberta = false
		registrar_evento(CatalogoEventos.SESSAO_ABANDONADA, {"motivo": "processo_encerrado"})
		_encerramento_pendente = {
			"id_sessao": _id_sessao,
			"status": STATUS_ABANDONADA,
			"encerrada_em": Relogio.agora_utc_iso(),
		}
		_persistir()


func _converter_lista(bruto: Variant) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if typeof(bruto) != TYPE_ARRAY:
		return saida
	for item: Variant in bruto as Array:
		if typeof(item) == TYPE_DICTIONARY:
			saida.append(item as Dictionary)
	return saida


# ---------------------------------------------------------------------------
# Sanitizacao (restricoes 1 e 2 da secao 4)
# ---------------------------------------------------------------------------

static var _re_controle: RegEx = RegEx.create_from_string("[\\x00-\\x1f\\x7f]")
static var _re_espacos: RegEx = RegEx.create_from_string("\\s+")


## Remove caractere de controle, colapsa espaco e trunca. O truncamento vale
## para tudo que possa ter vindo de teclado: um jogador que digitar o proprio
## nome no terminal nao pode gerar um registro com 3 mil caracteres de texto
## livre no banco de pesquisa.
func _sanitizar_texto(texto: String, limite: int) -> String:
	var limpo: String = _re_controle.sub(texto, " ", true)
	limpo = _re_espacos.sub(limpo, " ", true).strip_edges()
	if limpo.length() > limite:
		limpo = limpo.substr(0, limite)
	return limpo


func _sanitizar_payload(payload: Dictionary, profundidade: int) -> Dictionary:
	var saida: Dictionary = {}
	if profundidade > PROFUNDIDADE_MAXIMA_PAYLOAD:
		Registro.aviso("Telemetria", "payload mais profundo que o limite; ramo cortado")
		return saida

	for chave: Variant in payload:
		var nome: String = _sanitizar_texto(String(chave), LIMITE_DESAFIO)
		saida[nome] = _sanitizar_valor(payload[chave], profundidade)
	return saida


func _sanitizar_valor(valor: Variant, profundidade: int) -> Variant:
	match typeof(valor):
		TYPE_STRING, TYPE_STRING_NAME:
			return _sanitizar_texto(String(valor), LIMITE_TEXTO_LIVRE)
		TYPE_DICTIONARY:
			return _sanitizar_payload(valor as Dictionary, profundidade + 1)
		TYPE_ARRAY:
			var lista: Array = []
			for item: Variant in valor as Array:
				lista.append(_sanitizar_valor(item, profundidade + 1))
			return lista
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return valor
		TYPE_VECTOR2, TYPE_VECTOR2I:
			# Posicao no labirinto e dado de jogo legitimo, mas JSON nao conhece
			# Vector2: converter aqui evita que JSON.stringify emita "(3, 4)".
			var v: Vector2 = valor as Vector2
			return {"x": v.x, "y": v.y}
		_:
			return _sanitizar_texto(str(valor), LIMITE_TEXTO_LIVRE)


func _sanitizar_tokens(tokens: Array[Dictionary]) -> Array:
	var saida: Array = []
	for token: Dictionary in tokens:
		saida.append({
			"tipo": _sanitizar_texto(String(token.get("tipo", "")), LIMITE_CODIGO_ERRO),
			"lexema": _sanitizar_texto(String(token.get("lexema", "")), LIMITE_LEXEMA),
			"posicao": int(token.get("posicao", 0)),
		})
	return saida


# ---------------------------------------------------------------------------
# Transporte
# ---------------------------------------------------------------------------

func _selecionar_transporte() -> void:
	if ConfigJogo.modo_telemetria == ConfigJogo.MODO_HTTP and TransporteHttp.disponivel():
		configurar(
			TransporteHttp.new(ConfigJogo.url_api, ConfigJogo.chave_api),
			CAMINHO_FILA_PADRAO)
		return

	if ConfigJogo.modo_telemetria == ConfigJogo.MODO_HTTP:
		# Nao seguir em frente calado: modo HTTP sem transporte deixaria a fila
		# crescer sem destino, o que e pior que gravar em disco local.
		Registro.erro("Telemetria",
			"modo HTTP pedido mas o transporte chega no Marco 3; caindo para MOCK")
	configurar(TransporteMock.new(TransporteMock.CAMINHO_PADRAO), CAMINHO_FILA_PADRAO)
