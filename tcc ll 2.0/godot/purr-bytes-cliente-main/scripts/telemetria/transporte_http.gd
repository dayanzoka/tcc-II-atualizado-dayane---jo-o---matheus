class_name TransporteHttp
extends TransporteTelemetria

## Transporte HTTP -- fala com a API de ingestao (ou, em desenvolvimento, com
## o servidor de eco de tools/servidor_eco.py) usando HTTPRequest, o no
## assincrono nativo da secao 2 do CLAUDE.md. Nao ha requisicao concorrente:
## Telemetria.descarregar() so chama enviar() de novo depois de aguardar o
## anterior (secao 8), entao um unico HTTPRequest filho, reaproveitado a cada
## chamada, e suficiente e mais simples que um por requisicao.
##
## Authorization: Bearer <chave_api> vai no cabecalho -- nunca em log, nunca
## na tela (restricao 8 da secao 4).

var url_base: String = ""
var chave_api: String = ""

var _http: HTTPRequest = null


func _init(url_base_: String = "", chave_api_: String = "") -> void:
	url_base = url_base_
	chave_api = chave_api_


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "RequisicaoHttp"
	add_child(_http)


static func disponivel() -> bool:
	return true


func rotulo() -> String:
	return "HTTP(%s)" % url_base


func enviar(pacote: Dictionary) -> ResultadoEnvio:
	await _ceder_quadro()

	var rota: String = String(pacote.get("rota", ""))
	var id_sessao: String = String(pacote.get("id_sessao", ""))
	var caminho: String = caminho_da_rota(rota, id_sessao)
	if caminho.is_empty():
		return ResultadoEnvio.falha_permanente("rota desconhecida: %s" % rota)

	var corpo: Dictionary = _corpo_do_pacote(pacote, rota)
	if corpo.is_empty():
		return ResultadoEnvio.falha_permanente("pacote sem corpo reconhecivel para a rota %s" % rota)

	var cabecalhos: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % chave_api,
	])

	var erro: Error = _http.request(
		url_base + caminho, cabecalhos, HTTPClient.METHOD_POST, JSON.stringify(corpo))
	if erro != OK:
		# Erro de montagem da requisicao (URL invalida, etc.) -- nao ha lote
		# malformado aqui, entao transitorio: uma URL configurada errada nao
		# deveria descartar dado de pesquisa, so acumular ate alguem notar.
		return ResultadoEnvio.falha_transitoria("HTTPRequest.request() recusou (erro %d)" % erro)

	var resposta: Array = await _http.request_completed
	var resultado: int = resposta[0] as int
	var codigo_http: int = resposta[1] as int

	if resultado != HTTPRequest.RESULT_SUCCESS:
		return ResultadoEnvio.falha_transitoria(
			"falha de rede antes de qualquer resposta HTTP (resultado %d)" % resultado)

	if codigo_http >= 200 and codigo_http < 300:
		return ResultadoEnvio.ok("HTTP %d" % codigo_http)
	if codigo_http >= 400 and codigo_http < 500:
		return ResultadoEnvio.falha_permanente("HTTP %d" % codigo_http)
	return ResultadoEnvio.falha_transitoria("HTTP %d" % codigo_http)


## A rota concreta de cada pacote.
func caminho_da_rota(rota: String, id_sessao: String) -> String:
	match rota:
		ROTA_ABRIR_SESSAO:
			return "/v1/sessoes"
		ROTA_EVENTOS:
			return "/v1/sessoes/%s/eventos" % id_sessao
		ROTA_TENTATIVAS:
			return "/v1/sessoes/%s/tentativas" % id_sessao
		ROTA_ENCERRAR_SESSAO:
			return "/v1/sessoes/%s/encerrar" % id_sessao
		_:
			Registro.erro("TransporteHttp", "rota desconhecida: %s" % rota)
			return ""


## Corpo JSON exato por rota -- docs/contrato-telemetria.md documenta cada um
## com um exemplo real, gerado por este mesmo caminho de codigo.
func _corpo_do_pacote(pacote: Dictionary, rota: String) -> Dictionary:
	match rota:
		ROTA_ABRIR_SESSAO, ROTA_ENCERRAR_SESSAO:
			return pacote.get("corpo", {}) as Dictionary
		ROTA_EVENTOS:
			var eventos: Array = pacote.get("eventos", [])
			return {} if eventos.is_empty() else {"eventos": eventos}
		ROTA_TENTATIVAS:
			var tentativas: Array = pacote.get("tentativas", [])
			return {} if tentativas.is_empty() else {"tentativas": tentativas}
	return {}
