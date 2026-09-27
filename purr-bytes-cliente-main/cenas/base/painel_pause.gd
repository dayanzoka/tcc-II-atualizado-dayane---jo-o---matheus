class_name PainelDePause
extends CanvasLayer

## Menu de pause: o unico jeito de sair de uma fase sem perder o progresso por
## engano (antes, a tecla de pausa chamava abandonar() direto -- um ESC
## sem querer descartava a tentativa).
##
## Mesmo mecanismo de pausa que o terminal e a caixa de puzzle ja usam
## (get_tree().paused). process_mode ALWAYS aqui pelo mesmo motivo do
## terminal: com a arvore pausada por este proprio painel, so um no ALWAYS
## continua recebendo input -- e como fecha de novo.
##
## FaseBase e quem liga/desliga get_tree().paused e decide o que "reiniciar"
## e "voltar ao menu" fazem; este no so cuida da propria visibilidade, do
## foco e de avisar por sinal.

signal continuar_pressionado()
signal reiniciar_pressionado()
signal voltar_ao_menu_pressionado()

@onready var _botao_continuar: Button = $Raiz/Painel/Coluna/Continuar
@onready var _botao_reiniciar: Button = $Raiz/Painel/Coluna/Reiniciar
@onready var _botao_voltar: Button = $Raiz/Painel/Coluna/Voltar


func _ready() -> void:
	visible = false
	_botao_continuar.pressed.connect(fechar)
	_botao_reiniciar.pressed.connect(func() -> void: reiniciar_pressionado.emit())
	_botao_voltar.pressed.connect(func() -> void: voltar_ao_menu_pressionado.emit())


## So fecha (equivale a "continuar"): FaseBase decide despausar a partir do
## sinal. "Reiniciar" e "voltar ao menu" trocam ou recarregam a cena inteira,
## entao nao passam por aqui.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("pausar"):
		get_viewport().set_input_as_handled()
		fechar()


func abrir() -> void:
	visible = true
	_botao_continuar.grab_focus()


func fechar() -> void:
	visible = false
	continuar_pressionado.emit()


func esta_aberto() -> bool:
	return visible
