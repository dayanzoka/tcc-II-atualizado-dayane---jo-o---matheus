class_name Terminal
extends CanvasLayer

## Terminal de comandos -- a superficie do analisador lexico-sintatico.
##
## Marco 0 entrega a janela: abrir, fechar, escrever, ler a linha e cronometrar.
## O analisador (AFD + parser recursivo descendente) entra no Marco 1 e vai
## consumir o sinal comando_submetido; nenhuma linha de gramatica mora aqui.
##
## O cronometro comeca quando o terminal ganha foco e para no Enter. E ele que
## produz tentativa_comando.tempo_resposta_ms, uma das tres metricas objetivas
## de aprendizado do Eixo 1 -- por isso usa relogio monotonico, e nao data.

signal comando_submetido(texto: String, tempo_resposta_ms: int)
signal aberto()
signal fechado()

const MAXIMO_DE_LINHAS: int = 200

@onready var _saida: RichTextLabel = $Painel/Margem/Coluna/Saida
@onready var _entrada: LineEdit = $Painel/Margem/Coluna/Entrada

var _marca_de_foco: int = 0
var _linhas: int = 0


func _ready() -> void:
	_entrada.text_submitted.connect(_ao_submeter)
	visible = false


## Abrir o terminal pausa a arvore (FaseBase faz isso ao receber `aberto`), e no
## pausado o _unhandled_input da fase nao roda. Por isso a tecla de FECHAR e
## tratada aqui, no proprio terminal, que tem process_mode ALWAYS -- como ja
## acontece na caixa de puzzle. Sem isto, abrir o terminal seria uma armadilha:
## o jogo pausado e nenhuma tecla capaz de sair.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("abrir_terminal") or evento.is_action_pressed("pausar"):
		get_viewport().set_input_as_handled()
		fechar()


func abrir(cabecalho: String = "") -> void:
	visible = true
	if cabecalho != "":
		escrever(cabecalho)
	_entrada.clear()
	_entrada.grab_focus()
	_marca_de_foco = Relogio.marca_ms()
	aberto.emit()


func fechar() -> void:
	visible = false
	_entrada.release_focus()
	fechado.emit()


func esta_aberto() -> bool:
	return visible


func escrever(linha: String) -> void:
	# Teto de linhas: uma partida longa com muitos comandos faria o
	# RichTextLabel crescer sem limite e comer quadro na maquina da escola.
	if _linhas >= MAXIMO_DE_LINHAS:
		_saida.clear()
		_linhas = 0
	_saida.append_text(linha + "\n")
	_linhas += 1


func limpar() -> void:
	_saida.clear()
	_linhas = 0


func _ao_submeter(texto: String) -> void:
	var decorrido: int = Relogio.decorrido_ms(_marca_de_foco)
	_entrada.clear()
	# O cronometro reinicia aqui: a proxima tentativa do mesmo desafio conta a
	# partir do momento em que o jogador pode digitar de novo.
	_marca_de_foco = Relogio.marca_ms()
	comando_submetido.emit(texto, decorrido)
