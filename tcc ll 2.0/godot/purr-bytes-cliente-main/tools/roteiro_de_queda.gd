class_name RoteiroDeQueda
extends RefCounted

## Demonstracao do criterio de aceite "matar o processo com a fila cheia e
## reabrir: a fila e recuperada do disco" -- com dois processos de verdade.
##
##   godot --headless --path . --script res://tools/simular_queda.gd -- encher
##   godot --headless --path . --script res://tools/simular_queda.gd -- drenar
##
## O primeiro comando enfileira uma partida com a "rede fora" e morre sem
## conseguir enviar nada. O segundo e um processo novo: le a fila do disco e
## drena. tests/teste_telemetria.gd cobre o mesmo caminho dentro de um processo
## so; isto aqui e a versao que se mostra para a banca.

const DIRETORIO: String = "user://queda"
const EVENTOS: int = 20


## Transporte que sempre falha de forma transitoria: e o comportamento de uma
## API fora do ar ou de uma rede de escola instavel.
class RedeFora extends TransporteTelemetria:
	func rotulo() -> String:
		return "REDE_FORA"

	func enviar(_pacote: Dictionary) -> ResultadoEnvio:
		await _ceder_quadro()
		return ResultadoEnvio.falha_transitoria("rede fora (simulado)")


func encher() -> void:
	DirAccess.make_dir_recursive_absolute(DIRETORIO)
	_limpar()

	Telemetria.reiniciar(RedeFora.new(), _caminho_fila())
	var id_sessao: String = Identificador.uuid_v4()
	Telemetria.iniciar_sessao(id_sessao, ConfigJogo.id_sujeito)
	for i: int in EVENTOS:
		Telemetria.registrar_evento(CatalogoEventos.COMANDO_SUBMETIDO, {"indice": i}, 1)

	await Telemetria.descarregar()

	print("[processo 1] id_sessao: %s" % id_sessao)
	print("[processo 1] nada foi enviado: %s" % JSON.stringify(Telemetria.estatisticas()))
	print("[processo 1] fila em disco: %s bytes"
		% FileAccess.get_file_as_bytes(_caminho_fila()).size())
	print("[processo 1] processo encerrado sem encerrar a sessao")


func drenar() -> void:
	# Processo novo: nada em memoria, tudo no disco.
	Telemetria.reiniciar(TransporteMock.new(_caminho_jsonl()), _caminho_fila())
	print("[processo 2] antes de ler o disco: %s" % JSON.stringify(Telemetria.estatisticas()))

	Telemetria.recuperar_fila()
	print("[processo 2] depois de ler o disco: %s" % JSON.stringify(Telemetria.estatisticas()))

	for i: int in 50:
		await Telemetria.descarregar()
		if Telemetria.fila_vazia():
			break

	var eventos: int = 0
	var sequencias: Array[int] = []
	var arquivo: FileAccess = FileAccess.open(_caminho_jsonl(), FileAccess.READ)
	while not arquivo.eof_reached():
		var linha: String = arquivo.get_line().strip_edges()
		if linha.is_empty():
			continue
		var registro: Dictionary = JSON.parse_string(linha) as Dictionary
		if String(registro["tipo_registro"]) == "evento":
			eventos += 1
			sequencias.append(int((registro["dados"] as Dictionary)["sequencia"]))
	arquivo.close()

	var contiguas: bool = true
	for i: int in sequencias.size():
		if sequencias[i] != i:
			contiguas = false

	print("[processo 2] eventos entregues: %d (esperado %d)" % [eventos, EVENTOS + 2])
	print("[processo 2] sequencia contigua de 0 a %d: %s"
		% [sequencias.size() - 1, "sim" if contiguas else "NAO"])
	print("[processo 2] fila ao final: %s" % JSON.stringify(Telemetria.estatisticas()))


func _caminho_fila() -> String:
	return "%s/fila.json" % DIRETORIO


func _caminho_jsonl() -> String:
	return "%s/telemetria.jsonl" % DIRETORIO


func _limpar() -> void:
	for caminho: String in [_caminho_fila(), _caminho_jsonl()]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(caminho)
