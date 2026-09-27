extends SceneTree

## Ver tools/roteiro_de_queda.gd. Uso:
##   godot --headless --path . --script res://tools/simular_queda.gd -- encher
##   godot --headless --path . --script res://tools/simular_queda.gd -- drenar
##
## O roteiro fica em outro arquivo porque script passado em --script e compilado
## antes de os autoloads existirem.

const ROTEIRO: String = "res://tools/roteiro_de_queda.gd"


func _initialize() -> void:
	_executar()


func _executar() -> void:
	await process_frame

	var etapa: String = ""
	for argumento: String in OS.get_cmdline_user_args():
		if not argumento.begins_with("-"):
			etapa = argumento

	if etapa != "encher" and etapa != "drenar":
		print("uso: --script res://tools/simular_queda.gd -- [encher|drenar]")
		quit(1)
		return

	var roteiro: RefCounted = load(ROTEIRO).new()
	await roteiro.call(etapa)
	quit(0)
