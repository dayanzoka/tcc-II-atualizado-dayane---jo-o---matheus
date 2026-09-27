class_name ResultadoEnvio
extends RefCounted

## Veredito de uma tentativa de envio de pacote de telemetria.
##
## A distincao entre falha permanente e transitoria e o que decide o destino do
## lote (secao 8 do CLAUDE.md):
##   2xx  -> sucesso, remove da fila
##   4xx  -> permanente: o lote esta malformado, reenviar da o mesmo erro para
##           sempre. Descarta e loga alto.
##   5xx / rede -> transitoria: preserva a fila e tenta de novo com backoff.
## Confundir os dois e como se perde dado de pesquisa em silencio.

var sucesso: bool = false
var permanente: bool = false
var detalhe: String = ""


static func ok(detalhe_: String = "") -> ResultadoEnvio:
	var r := ResultadoEnvio.new()
	r.sucesso = true
	r.detalhe = detalhe_
	return r


static func falha_permanente(detalhe_: String) -> ResultadoEnvio:
	var r := ResultadoEnvio.new()
	r.permanente = true
	r.detalhe = detalhe_
	return r


static func falha_transitoria(detalhe_: String) -> ResultadoEnvio:
	var r := ResultadoEnvio.new()
	r.detalhe = detalhe_
	return r
