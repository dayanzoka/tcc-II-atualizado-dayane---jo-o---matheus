extends CasoDeTeste

## O InputMap e gerado por tools/configurar_entrada.gd, que serializa constantes
## KEY_* em codigos numericos. Um numero errado nao quebra nada visivelmente --
## a tecla so nao responde. Este arquivo transforma isso em falha de suite.

const ACOES_ESPERADAS: PackedStringArray = [
	"mover_cima", "mover_baixo", "mover_esquerda", "mover_direita",
	"abrir_terminal", "pausar", "alternar_depuracao",
]


func teste_todas_as_acoes_existem() -> void:
	for acao: String in ACOES_ESPERADAS:
		afirmar_verdadeiro(InputMap.has_action(acao), "acao registrada: %s" % acao)


func teste_teclas_de_movimento() -> void:
	_afirmar_tecla("mover_cima", KEY_W)
	_afirmar_tecla("mover_cima", KEY_UP)
	_afirmar_tecla("mover_baixo", KEY_S)
	_afirmar_tecla("mover_baixo", KEY_DOWN)
	_afirmar_tecla("mover_esquerda", KEY_A)
	_afirmar_tecla("mover_esquerda", KEY_LEFT)
	_afirmar_tecla("mover_direita", KEY_D)
	_afirmar_tecla("mover_direita", KEY_RIGHT)


func teste_teclas_de_sistema() -> void:
	_afirmar_tecla("abrir_terminal", KEY_T)
	_afirmar_tecla("abrir_terminal", KEY_ENTER)
	_afirmar_tecla("pausar", KEY_ESCAPE)
	_afirmar_tecla("alternar_depuracao", KEY_F3)


## O que de fato importa: um evento vindo de um teclado real (device 0) casa com
## a acao gravada no project.godot. Se o campo device gravado fosse restritivo
## demais, todas as acoes existiriam e nenhuma responderia.
func teste_evento_real_dispara_a_acao() -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = KEY_W
	evento.pressed = true
	evento.device = 0

	afirmar_verdadeiro(evento.is_action("mover_cima"),
		"tecla fisica W casa com mover_cima vinda do teclado")
	afirmar_falso(evento.is_action("mover_baixo"), "e nao casa com outra acao")


func teste_usa_tecla_fisica_e_nao_logica() -> void:
	# physical_keycode mantem o WASD no mesmo lugar em ABNT2, AZERTY e QWERTY.
	for acao: String in ["mover_cima", "mover_baixo", "mover_esquerda", "mover_direita"]:
		for evento: InputEvent in InputMap.action_get_events(acao):
			var tecla := evento as InputEventKey
			if tecla == null:
				continue
			afirmar_verdadeiro(tecla.physical_keycode != KEY_NONE,
				"%s usa physical_keycode" % acao)
			afirmar_igual(tecla.keycode, KEY_NONE,
				"%s nao depende do layout logico do teclado" % acao)


func _afirmar_tecla(acao: String, tecla: Key) -> void:
	for evento: InputEvent in InputMap.action_get_events(acao):
		var como_tecla := evento as InputEventKey
		if como_tecla != null and como_tecla.physical_keycode == tecla:
			afirmar_verdadeiro(true, "%s aceita %s" % [acao, OS.get_keycode_string(tecla)])
			return
	falhar("%s nao tem a tecla %s" % [acao, OS.get_keycode_string(tecla)])
