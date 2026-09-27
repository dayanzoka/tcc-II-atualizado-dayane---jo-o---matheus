class_name Relogio
extends RefCounted

## Fonte unica de tempo para a telemetria.
##
## Restricao 4 da secao 4 do CLAUDE.md: dois relogios. O cliente grava
## ocorrido_em, o servidor grava recebido_em, e a diferenca entre os dois e o
## que mede a defasagem (purrbytes.ingestao.max-defasagem-relogio-minutos).
## Corrigir o relogio do cliente aqui destruiria justamente essa medida.
##
## Por que nao usar Time.get_datetime_string_from_system(true, true) direto,
## como o briefing sugeria: com use_space = true a saida e "2026-08-21 22:36:01"
## -- separador de espaco e, pior, sem designador de fuso. Um TIMESTAMPTZ do
## PostgreSQL recebendo string sem fuso assume o fuso da sessao do banco, o que
## deslocaria silenciosamente todo ocorrido_em em algumas horas. Aqui a saida e
## ISO-8601 com "T" e "Z" explicito.

## Resolucao de segundo nao basta: COMANDO_SUBMETIDO e ERRO_LEXICO caem no mesmo
## segundo com frequencia, e tempo_resposta_ms e uma metrica do Eixo 1.
static func agora_utc_iso() -> String:
	var epoch: float = Time.get_unix_time_from_system()
	var segundos: int = int(floor(epoch))
	var milissegundos: int = int(round((epoch - float(segundos)) * 1000.0))
	if milissegundos >= 1000:
		segundos += 1
		milissegundos = 0
	return "%sT%s.%03dZ" % [
		Time.get_date_string_from_unix_time(segundos),
		Time.get_time_string_from_unix_time(segundos),
		milissegundos,
	]


## Relogio monotonico para medir duracao (tempo_resposta_ms do terminal).
## Nao usar agora_utc_iso() para isso: se o sistema ajustar a hora por NTP no
## meio de uma tentativa, a subtracao daria negativo e violaria a constraint
## ck_tentativa_tempo (tempo_resposta_ms >= 0).
static func marca_ms() -> int:
	return Time.get_ticks_msec()


static func decorrido_ms(marca_inicial: int) -> int:
	return maxi(0, Time.get_ticks_msec() - marca_inicial)


## Inverso de agora_utc_iso(): "2026-09-24T23:39:59.249Z" -> ms desde a epoca.
## Devolve -1 para texto fora do formato, em vez de 0 -- 0 e uma data valida
## (1970), e somar duracao com ele produziria uma partida de 56 anos.
##
## Time.get_unix_time_from_datetime_string() nao aceita a fracao nem o "Z",
## entao os dois sao separados aqui e o resto fica com a funcao nativa.
static func iso_para_unix_ms(texto: String) -> int:
	var limpo: String = texto.strip_edges().trim_suffix("Z")
	if limpo.length() < 19 or limpo[10] != "T":
		return -1
	var milissegundos: int = 0
	var ponto: int = limpo.find(".")
	if ponto != -1:
		var fracao: String = limpo.substr(ponto + 1).left(3).rpad(3, "0")
		if not fracao.is_valid_int():
			return -1
		milissegundos = fracao.to_int()
		limpo = limpo.left(ponto)
	var segundos: int = Time.get_unix_time_from_datetime_string(limpo)
	if segundos == 0 and not limpo.begins_with("1970-01-01T00:00:00"):
		return -1
	return segundos * 1000 + milissegundos
