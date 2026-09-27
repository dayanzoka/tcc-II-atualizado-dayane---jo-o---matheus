class_name AnimadorDirecional
extends AnimatedSprite2D

## Escolhe a animacao de andar pela direcao da velocidade do corpo.
##
## AnimatedSprite2D + SpriteFrames (e nao AnimationPlayer mexendo em
## Sprite2D.frame) porque aqui a animacao e so "qual quadro da folha mostrar":
## SpriteFrames guarda isso como dado, editavel no painel SpriteFrames do
## editor, e o no ja cuida do tempo de cada quadro.
##
## Gato e cachorro usam este mesmo script (regra de ouro da secao 3: a mesma
## linha em dois personagens pertence a um lugar so). A folha dos dois segue a
## mesma grade -- ver tools/gerar_sprite_frames.gd.

const ANDAR_BAIXO: StringName = &"andar_baixo"
const ANDAR_CIMA: StringName = &"andar_cima"
const ANDAR_DIREITA: StringName = &"andar_direita"
const ANDAR_ESQUERDA: StringName = &"andar_esquerda"
const PARADO: StringName = &"parado"
const DESCANSAR: StringName = &"descansar"

## Abaixo disto o corpo esta "parado": o lerp do jogador leva alguns quadros
## para zerar, e sem limiar o gato ficaria andando no lugar ao soltar a tecla.
@export_range(0.0, 50.0, 0.5) var velocidade_minima: float = 6.0

## Velocidade em que a animacao roda no ritmo gravado no SpriteFrames. Mais
## rapido que isso acelera os passos na mesma proporcao, para o pe nao
## "patinar" no chao quando o cachorro corre.
@export_range(1.0, 300.0, 1.0) var velocidade_de_referencia: float = 60.0

## Para folhas sem vista de costas (a do cachorro): andando na vertical, o
## personagem continua na ultima lateral em vez de mostrar a frente -- de
## frente, sentado, ele pareceria deslizar pelo corredor.
@export var lateral_no_eixo_vertical: bool = false

var _ultima_lateral: StringName = ANDAR_DIREITA


func _ready() -> void:
	if sprite_frames != null and sprite_frames.has_animation(PARADO):
		play(PARADO)


## Chamado pelo dono depois do move_and_slide(), com a velocidade real.
func atualizar(velocidade: Vector2) -> void:
	var nome: StringName = animacao_para(velocidade)
	if nome == ANDAR_DIREITA or nome == ANDAR_ESQUERDA:
		_ultima_lateral = nome
	if nome == PARADO:
		speed_scale = 1.0
	else:
		speed_scale = maxf(1.0, velocidade.length() / velocidade_de_referencia)
	if animation != nome or not is_playing():
		play(nome)


## Chamado pelo Jogador apos alguns segundos sem entrada (ver
## tempo_sem_entrada_para_descansar_s em jogador.gd). So troca de fato se a
## SpriteFrames tiver a animacao "descansar" -- e por isso que o Cachorro, que
## usa este MESMO script (regra de ouro da secao 3), nunca entra nesse estado:
## ninguem chama descansar() nele, e cachorro_frames.tres nem precisa da
## animacao para o resto do script continuar funcionando normalmente.
func descansar() -> void:
	if sprite_frames != null and sprite_frames.has_animation(DESCANSAR) and animation != DESCANSAR:
		speed_scale = 1.0
		play(DESCANSAR)


## Separada de atualizar() para ser testavel sem SceneTree: e a regra inteira
## (eixo dominante decide; empate fica no horizontal). Nao muda estado -- a
## ultima lateral so e lembrada por atualizar().
func animacao_para(velocidade: Vector2) -> StringName:
	if velocidade.length() < velocidade_minima:
		return PARADO
	if absf(velocidade.x) >= absf(velocidade.y):
		return ANDAR_DIREITA if velocidade.x > 0.0 else ANDAR_ESQUERDA
	if lateral_no_eixo_vertical:
		return _ultima_lateral
	return ANDAR_BAIXO if velocidade.y > 0.0 else ANDAR_CIMA
