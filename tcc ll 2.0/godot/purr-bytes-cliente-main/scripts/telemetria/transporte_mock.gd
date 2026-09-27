class_name TransporteMock
extends TransporteTelemetria

## Transporte MOCK: grava cada pacote como linhas JSONL em disco.
##
## Nao e um "modo de desenvolvimento" descartavel. E o fallback previsto no plano
## B do risco de integracao (docs/arquitetura/visao-geral.md, secao 2.3) e, na
## pratica, o instrumento de verificacao do projeto: os criterios de aceite dos
## Marcos 0 e 1 sao checados lendo este arquivo. Se a API estiver fora no dia da
## coleta, este arquivo E o dado da pesquisa -- e por isso ele sai no mesmo
## formato que iria para a rede, campo a campo.
##
## Uma linha por registro (JSONL e nao JSON) porque o arquivo cresce durante a
## partida e precisa sobreviver a um processo morto no meio da escrita: perde-se
## no maximo a ultima linha, nunca o arquivo inteiro.

const CAMINHO_PADRAO: String = "user://telemetria_mock.jsonl"

var _caminho: String = CAMINHO_PADRAO
var linhas_escritas: int = 0


func _init(caminho: String = CAMINHO_PADRAO) -> void:
	_caminho = caminho


func rotulo() -> String:
	return "MOCK(%s)" % _caminho


func caminho() -> String:
	return _caminho


func enviar(pacote: Dictionary) -> ResultadoEnvio:
	await _ceder_quadro()

	var linhas: PackedStringArray = _linhas_do_pacote(pacote)
	if linhas.is_empty():
		return ResultadoEnvio.falha_permanente("pacote sem conteudo reconhecivel")

	var arquivo: FileAccess = FileAccess.open(_caminho, FileAccess.READ_WRITE)
	if arquivo == null:
		arquivo = FileAccess.open(_caminho, FileAccess.WRITE)
	if arquivo == null:
		# Disco cheio ou sem permissao: transitorio de proposito, para a fila
		# segurar o dado em memoria em vez de descartar.
		return ResultadoEnvio.falha_transitoria(
			"nao foi possivel abrir %s (erro %d)" % [_caminho, FileAccess.get_open_error()])

	arquivo.seek_end()
	for linha: String in linhas:
		arquivo.store_line(linha)
	arquivo.close()

	linhas_escritas += linhas.size()
	return ResultadoEnvio.ok("%d linha(s) em %s" % [linhas.size(), _caminho])


## Espelha o que o cliente HTTP enviaria: um registro por objeto que iria no
## corpo da requisicao, com a rota preservada. Ver docs/contrato-telemetria.md.
func _linhas_do_pacote(pacote: Dictionary) -> PackedStringArray:
	var linhas := PackedStringArray()
	var rota: String = String(pacote.get("rota", ""))

	match rota:
		ROTA_ABRIR_SESSAO, ROTA_ENCERRAR_SESSAO:
			linhas.append(_linha(rota, "sessao", pacote.get("corpo", {})))
		ROTA_EVENTOS:
			for evento: Dictionary in pacote.get("eventos", [] as Array):
				linhas.append(_linha(rota, "evento", evento))
		ROTA_TENTATIVAS:
			for tentativa: Dictionary in pacote.get("tentativas", [] as Array):
				linhas.append(_linha(rota, "tentativa", tentativa))
		_:
			Registro.erro("TransporteMock", "rota desconhecida: %s" % rota)

	return linhas


func _linha(rota: String, tipo_registro: String, dados: Variant) -> String:
	return JSON.stringify({
		"rota": rota,
		"tipo_registro": tipo_registro,
		"escrito_em": Relogio.agora_utc_iso(),
		"dados": dados,
	})
