extends CasoDeTeste

## ocorrido_em vai para uma coluna TIMESTAMPTZ. String sem designador de fuso e
## interpretada no fuso da sessao do banco -- o erro silencioso que desloca todo
## o eixo do tempo da pesquisa. Este arquivo existe para esse erro nao voltar.


func teste_formato_iso_8601_utc() -> void:
	var agora: String = Relogio.agora_utc_iso()
	var padrao := RegEx.create_from_string(
		"^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$")
	afirmar_nao_nulo(padrao.search(agora),
		"formato AAAA-MM-DDTHH:MM:SS.mmmZ, obtido '%s'" % agora)
	afirmar_falso(agora.contains(" "), "sem espaco separando data e hora")
	afirmar_verdadeiro(agora.ends_with("Z"), "termina em Z (UTC explicito)")


func teste_e_utc_e_nao_hora_local() -> void:
	var utc: String = Relogio.agora_utc_iso()
	var deslocamento: int = int(Time.get_time_zone_from_system().get("bias", 0))
	if deslocamento == 0:
		return  # maquina em UTC: nada a distinguir
	var local: String = Time.get_datetime_string_from_system(false, false)
	afirmar_diferente(utc.substr(0, 16), local.substr(0, 16),
		"o relogio da telemetria nao segue o fuso local da maquina")


func teste_parseavel_de_volta() -> void:
	# Se o Godot nao consegue reler o proprio carimbo, o Postgres tambem nao vai.
	var agora: String = Relogio.agora_utc_iso()
	var partes: Dictionary = Time.get_datetime_dict_from_datetime_string(
		agora.substr(0, 19), false)
	afirmar_igual(int(partes["year"]), int(Time.get_datetime_dict_from_system(true)["year"]),
		"ano reconhecido ao reler o carimbo")


func teste_duracao_nunca_negativa() -> void:
	var marca: int = Relogio.marca_ms()
	afirmar_verdadeiro(Relogio.decorrido_ms(marca) >= 0, "duracao imediata nao e negativa")
	# Marca no futuro simula ajuste de relogio no meio de uma tentativa: o
	# resultado tem que ser 0, nunca negativo, por causa da constraint
	# ck_tentativa_tempo (tempo_resposta_ms >= 0).
	afirmar_igual(Relogio.decorrido_ms(marca + 10_000), 0,
		"marca no futuro vira 0 e nao numero negativo")
