class_name TelaCaptura
extends CanvasLayer

## Tela de interceptacao.
##
## Enquadramento pedagogico, nao punitivo: ser pego custa vida e pontos e devolve
## o pacote ao inicio, mas nao encerra o jogo. O texto explica o porque -- que o
## pacote viajava em texto claro -- porque a tela de erro e o momento em que o
## jogador esta mais disposto a ler a explicacao.

signal encerrada()

@export_range(0.5, 10.0, 0.1) var duracao_s: float = 2.5
## Enter so fecha depois disto: quem esta segurando uma tecla ao ser pego nao
## pula a explicacao sem querer.
@export_range(0.0, 3.0, 0.1) var tempo_minimo_s: float = 0.6

var _aberta_em_ms: int = 0

@onready var _mensagem: Label = $Raiz/Painel/Coluna/Mensagem
@onready var _explicacao: Label = $Raiz/Painel/Coluna/Explicacao
@onready var _temporizador: Timer = $Temporizador


func _ready() -> void:
	visible = false
	# A fase pausa a arvore durante a captura (os cachorros nao podem seguir
	# andando ate o jogador parado); esta tela precisa continuar contando o
	# tempo e ouvindo o Enter mesmo assim -- o mesmo arranjo do terminal.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_temporizador.timeout.connect(_ao_terminar)


func mostrar(mensagem: String, explicacao: String) -> void:
	_mensagem.text = mensagem
	_explicacao.text = explicacao
	visible = true
	_aberta_em_ms = Time.get_ticks_msec()
	_temporizador.start(duracao_s)


func _input(evento: InputEvent) -> void:
	if not visible or not evento.is_action_pressed("ui_accept"):
		return
	if Time.get_ticks_msec() - _aberta_em_ms < int(tempo_minimo_s * 1000.0):
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	encerrar_agora()


## Fecha antes do tempo (Enter). Tambem e o ponto de entrada dos testes.
func encerrar_agora() -> void:
	if not visible:
		return
	_temporizador.stop()
	_ao_terminar()


func _ao_terminar() -> void:
	visible = false
	encerrada.emit()
