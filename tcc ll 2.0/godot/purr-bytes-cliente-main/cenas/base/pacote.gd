class_name Pacote
extends Area2D

## Um pacote de dados no labirinto. Nao decide nada: avisa que o jogador
## encostou e obedece quando mandam coletar -- quem decide se abre a caixa de
## puzzle ou coleta direto e fase_base.gd (secao 9: sinal de baixo para cima).
##
## Desenhado com _draw() em vez de Sprite2D porque nao existe arte de pacote
## ainda: um losango de 10px na cor de "dado em transito" e legivel no tile de
## 16 e some no dia em que a arte definitiva entrar, sem deixar arquivo orfao.

signal alcancado(pacote: Pacote)

const _COR_PACOTE: Color = Color(1.0, 0.82, 0.35)
const _COR_BORDA: Color = Color(0.25, 0.18, 0.05)
const _RAIO: float = 5.0

var configuracao: PacoteConfig = null
var coletado: bool = false

@onready var _colisao: CollisionShape2D = $Colisao


func _ready() -> void:
	body_entered.connect(_ao_entrar)


func _draw() -> void:
	if coletado:
		return
	var losango := PackedVector2Array([
		Vector2(0, -_RAIO), Vector2(_RAIO, 0), Vector2(0, _RAIO), Vector2(-_RAIO, 0),
	])
	draw_colored_polygon(losango, _COR_PACOTE)
	draw_polyline(losango + PackedVector2Array([Vector2(0, -_RAIO)]), _COR_BORDA, 1.0)


func definir(config: PacoteConfig) -> void:
	configuracao = config
	queue_redraw()


func coletar() -> void:
	if coletado:
		return
	coletado = true
	# Desligar a colisao adiado: o Area2D esta no meio da propria notificacao de
	# overlap quando isto e chamado, e mexer em CollisionShape2D dentro dela e
	# erro de fisica em andamento no Godot.
	_colisao.set_deferred("disabled", true)
	queue_redraw()


func _ao_entrar(corpo: Node2D) -> void:
	if coletado or not (corpo is Jogador):
		return
	alcancado.emit(self)
