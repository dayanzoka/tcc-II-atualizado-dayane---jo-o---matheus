class_name Cachorro
extends CharacterBody2D

## O cachorro farejador representa o interceptador na rede.
##
## Marco 0 entrega so o corpo: seguir um caminho ja calculado e avisar contato.
## Quem calcula o caminho e scripts/ia/navegacao.gd (AStarGrid2D, Marco 1), e
## quem decide para onde ir e o Diretor (Marco 2). A separacao e proposital: o
## cachorro nunca recebe a posicao do jogador de presente -- ele recebe um
## caminho ate um ponto, e esse ponto vem de crenca, nao de conhecimento.

signal contato_com_jogador(jogador: Node2D)
signal destino_alcancado()

@export_range(10.0, 200.0, 1.0) var velocidade: float = 45.0

## Distancia para considerar um ponto do caminho como alcancado. Menor que meia
## celula (8 px) faria o corpo orbitar o ponto sem nunca chegar.
@export_range(1.0, 16.0, 0.5) var tolerancia_de_chegada: float = 4.0

## Alcance maximo de LinhaDeVisao, normalmente copiado de
## FaseConfig.alcance_deteccao_cachorro por fase_base.gd -- fica com um default
## proprio para o no continuar valido se algum dia for instanciado fora de uma
## fase (ex: cena de teste isolada).
@export_range(8.0, 400.0, 1.0) var alcance_deteccao: float = 90.0

## Algoritmo que protege contra ESTE cachorro, e nada mais. Preenchido por
## fase_base.gd a partir do CachorroConfig da fase.
##
## A cor NAO sai daqui: ela e identidade visual (CachorroConfig.cor) e chega por
## definir_cor(). Separar as duas e o que permite trocar a aparencia -- ou
## troca-la por um sprite -- sem tocar na regra de protecao.
@export_enum("CESAR", "VIGENERE", "SHA256", "AES") var algoritmo_exigido: String = "CESAR"

## Vai para o payload de CACHORRO_DETECTOU/CACHORRO_PERDEU/JOGADOR_CAPTURADO:
## com varios cachorros em cena, "o cachorro detectou" sem dizer qual nao
## responde mais nenhuma pergunta de analise.
var identificador: String = "cachorro"

## Comando em texto livre que bloqueia este cachorro (fases de autoria). Vazio
## = ele obedece a regra por algoritmo das fases 1 a 3. Copiado do
## CachorroConfig por fase_base.gd.
var comando_para_bloquear: String = ""


func bloqueia_por_comando() -> bool:
	return not comando_para_bloquear.is_empty()

var _caminho: PackedVector2Array = PackedVector2Array()
var _indice: int = 0
## Cinza claro enquanto a fase nao definir: cachorro instanciado fora de uma
## fase (cena de teste isolada) continua visivel.
var _cor: Color = Color(0.85, 0.85, 0.85)

@onready var _area_de_contato: Area2D = $AreaDeContato
@onready var _linha_de_visao: RayCast2D = $LinhaDeVisao
@onready var _sprite: AnimadorDirecional = $Sprite
@onready var _marcador: MarcadorDeCor = $Marcador


func _ready() -> void:
	_area_de_contato.body_entered.connect(_ao_encostar)
	_linha_de_visao.enabled = false  # forcamos o update manualmente em tem_linha_de_visao()
	definir_cor(_cor)


func definir_algoritmo(algoritmo: String) -> void:
	algoritmo_exigido = algoritmo


## A cor vai para o anel no chao (MarcadorDeCor), nao para o sprite: a arte do
## cachorro e colorida, e tinge-la inteira misturaria o marrom do desenho com a
## cor que identifica o vigia.
func definir_cor(nova_cor: Color) -> void:
	_cor = nova_cor
	if _marcador != null:
		_marcador.cor = _cor


func cor() -> Color:
	return _cor


func _physics_process(_delta: float) -> void:
	_seguir_caminho()
	# velocity depois do move_and_slide e a velocidade real (ja com o deslize na
	# parede), entao o desenho vira para onde o corpo de fato anda.
	_sprite.atualizar(velocity)


func _seguir_caminho() -> void:
	if _indice >= _caminho.size():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var alvo: Vector2 = _caminho[_indice]
	if global_position.distance_to(alvo) <= tolerancia_de_chegada:
		_indice += 1
		if _indice >= _caminho.size():
			velocity = Vector2.ZERO
			move_and_slide()
			destino_alcancado.emit()
			return
		alvo = _caminho[_indice]

	# Sem o move_and_slide abaixo em TODO quadro, o quadro em que o waypoint e
	# alcancado ficava sem simulacao de fisica nenhuma -- o corpo "piscava"
	# parado a cada ponto do caminho, o que num labirinto de tile 16 e um
	# soluco visivel a cada 16 pixels percorridos.
	velocity = global_position.direction_to(alvo) * velocidade
	move_and_slide()


## Caminho em coordenadas de mundo, ja convertido de celulas pelo chamador.
func definir_caminho(pontos: PackedVector2Array) -> void:
	_caminho = pontos
	_indice = 0


func parar() -> void:
	_caminho = PackedVector2Array()
	_indice = 0
	velocity = Vector2.ZERO


func caminho_atual() -> PackedVector2Array:
	return _caminho


func indice_atual() -> int:
	return _indice


## Linha de visao direta ate alvo_global: falso se estiver fora de
## alcance_deteccao OU se uma parede do labirinto (RayCast2D.collision_mask = 1,
## a mesma camada fisica de TileMapLayer) cortar o caminho. Nao usa a posicao do
## jogador "de gracas" -- fase_base.gd chama isto a cada quadro exatamente
## porque a deteccao precisa ser tao responsiva quanto o jogo, mesmo com o
## replanejamento do A* rodando so por intervalo (secao 6 do CLAUDE.md).
## Contato em curso (e nao so o instante em que comecou): body_entered nao
## dispara de novo para quem ja estava dentro da area quando a
## invulnerabilidade do jogador acabou.
func esta_encostando(corpo: Node2D) -> bool:
	return _area_de_contato.overlaps_body(corpo)


func tem_linha_de_visao(alvo_global: Vector2) -> bool:
	if global_position.distance_to(alvo_global) > alcance_deteccao:
		return false
	_linha_de_visao.target_position = to_local(alvo_global)
	_linha_de_visao.force_raycast_update()
	return not _linha_de_visao.is_colliding()


func _ao_encostar(corpo: Node2D) -> void:
	if corpo is Jogador:
		contato_com_jogador.emit(corpo)
