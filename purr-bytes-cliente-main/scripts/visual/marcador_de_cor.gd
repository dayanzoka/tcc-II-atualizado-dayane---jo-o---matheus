class_name MarcadorDeCor
extends Node2D

## Anel colorido no chao, sob o personagem.
##
## Existe porque a cor do vigia e MECANICA (ADR 0010: cada cor tem o seu
## comando de bloqueio), e o cachorro agora e um desenho colorido: tingir o
## sprite inteiro com modulate escureceria a arte e confundiria marrom com a
## cor do vigia. O anel carrega a cor sem mexer no desenho.
##
## _draw() e nao um Sprite2D: e uma elipse de duas linhas, e desenhada por
## codigo ela aceita qualquer cor que o professor escolha no editor sem
## arquivo de imagem nenhum.

@export var cor: Color = Color.WHITE:
	set(valor):
		cor = valor
		queue_redraw()
@export_range(2.0, 16.0, 0.5) var raio: float = 8.0
## Elipse achatada = anel "deitado" no chao da vista de cima.
@export_range(0.2, 1.0, 0.05) var achatamento: float = 0.45
@export_range(0.0, 1.0, 0.05) var opacidade_do_preenchimento: float = 0.35
@export_range(0.5, 4.0, 0.5) var espessura: float = 1.5


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, achatamento))
	draw_circle(Vector2.ZERO, raio, Color(cor, opacidade_do_preenchimento))
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 24, cor, espessura)
