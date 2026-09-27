class_name Porta
extends Area2D

## O ponto de saida da fase, agora com estado: trancado ate o jogador ter todos
## os pacotes, aberto depois.
##
## Antes a saida era invisivel -- o jogador atravessava um pedaco de chao e a
## fase acabava. Uma porta que se ve trancada transforma "ande ate ali" em um
## objetivo: da para olhar do outro lado do labirinto e saber que ainda falta
## coisa, que e o que faz os pacotes valerem a pena procurar.
##
## Desenhada com _draw() pelo mesmo motivo de cenas/base/pacote.gd: nao ha arte
## de porta ainda, e uma forma geometrica legivel no tile de 16 nao deixa
## arquivo de imagem orfao quando a arte definitiva chegar.

const _COR_TRANCADA: Color = Color(0.85, 0.32, 0.32)
const _COR_ABERTA: Color = Color(0.40, 0.88, 0.52)
const _LADO: float = 14.0

var trancada: bool = true


func definir_trancada(valor: bool) -> void:
	if trancada == valor:
		return
	trancada = valor
	queue_redraw()


func _draw() -> void:
	var cor: Color = _COR_TRANCADA if trancada else _COR_ABERTA
	var quadro := Rect2(-_LADO / 2.0, -_LADO / 2.0, _LADO, _LADO)

	var fundo: Color = cor
	fundo.a = 0.22
	draw_rect(quadro, fundo)
	draw_rect(quadro, cor, false, 1.0)

	if trancada:
		# Cadeado: arco em cima, corpo embaixo. Duas primitivas bastam para a
		# leitura "isto esta fechado" a 16 pixels.
		draw_arc(Vector2(0, -1.0), 3.0, PI, TAU, 8, cor, 1.0)
		draw_rect(Rect2(-3.0, -1.0, 6.0, 5.0), cor)
	else:
		# Vao aberto: a barra vertical de um lado so, como uma porta escancarada.
		draw_line(Vector2(-2.0, -5.0), Vector2(-2.0, 5.0), cor, 1.0)
		draw_line(Vector2(-2.0, 0.0), Vector2(4.0, 0.0), cor, 1.0)
