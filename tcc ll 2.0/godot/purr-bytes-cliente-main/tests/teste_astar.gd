extends CasoDeTeste

## Oraculo do A*: o custo do caminho que o AStarGrid2D devolve -- via
## scripts/ia/navegacao.gd, o MESMO wrapper que o cachorro usa em jogo -- tem
## que bater com o da implementacao didatica (scripts/ia/astar_referencia.gd)
## em qualquer mapa. Divergencia aqui e sinal de bug: quem roda de verdade e
## navegacao.gd, mas o teste so aponta que os dois discordam, nao qual lado
## esta certo -- por isso o oraculo compara sempre os dois, nunca confia em um
## sozinho.
##
## O teste passa pela TileMapLayer real (nao so por uma matriz booleana solta)
## para exercitar tambem a leitura da camada "solido" e a conversao de
## coordenadas de Navegacao, que sao a parte deste arquivo que astar_referencia.gd
## nao tem.

const LARGURA: int = 12
const ALTURA: int = 8
const MAPAS: int = 100
const DENSIDADE_SOLIDA: float = 0.3

var _tileset: TileSet


func antes() -> void:
	_tileset = load("res://recursos/tilesets/labirinto.tres") as TileSet


func teste_custo_do_caminho_bate_com_a_referencia_em_100_mapas() -> void:
	var divergencias: PackedStringArray = PackedStringArray()

	for indice: int in MAPAS:
		var rng := RandomNumberGenerator.new()
		rng.seed = indice  # semente fixa: uma falha aqui e sempre reproduzivel

		var origem := Vector2i(0, 0)
		var destino := Vector2i(LARGURA - 1, ALTURA - 1)
		var solido: Array = _gerar_grade_solida(rng, origem, destino)

		var referencia: AStarReferencia.Resultado = AStarReferencia.calcular(
			func(celula: Vector2i) -> bool: return bool(solido[celula.y][celula.x]),
			LARGURA, ALTURA, origem, destino)

		var labirinto: TileMapLayer = _construir_tilemap(solido, LARGURA, ALTURA)
		var navegacao := Navegacao.new()
		navegacao.configurar(labirinto)
		var caminho: PackedVector2Array = navegacao.calcular_caminho(
			labirinto.map_to_local(origem), labirinto.map_to_local(destino))
		labirinto.queue_free()

		var achou_pelo_astargrid: bool = caminho.size() > 0
		if achou_pelo_astargrid != referencia.achou:
			divergencias.append("mapa %d: achou (referencia=%s, astargrid=%s)"
				% [indice, referencia.achou, achou_pelo_astargrid])
			continue

		if referencia.achou:
			var custo_astargrid: float = float(caminho.size() - 1)
			if not is_equal_approx(custo_astargrid, referencia.custo):
				divergencias.append("mapa %d: custo (referencia=%.0f, astargrid=%.0f)"
					% [indice, referencia.custo, custo_astargrid])

	afirmar_igual(divergencias.size(), 0,
		"%d/%d mapas com custo divergente: %s" % [divergencias.size(), MAPAS, str(divergencias)])


func teste_rota_desvia_de_parede_com_um_buraco() -> void:
	# 3 colunas x 3 linhas: parede vertical na coluna 1, com passagem so na
	# linha do meio -- o caminho tem que dar a volta por ali, nunca atravessar.
	var solido: Array = [
		[false, true, false],
		[false, false, false],
		[false, true, false],
	]
	var labirinto: TileMapLayer = _construir_tilemap(solido, 3, 3)
	var navegacao := Navegacao.new()
	navegacao.configurar(labirinto)

	var caminho: PackedVector2Array = navegacao.calcular_caminho(
		labirinto.map_to_local(Vector2i(0, 0)), labirinto.map_to_local(Vector2i(2, 0)))
	labirinto.queue_free()

	afirmar_verdadeiro(caminho.size() > 0, "existe caminho contornando a parede")
	afirmar_igual(caminho.size() - 1, 4, "o desvio pela linha do meio custa 4 passos, nao 2")


## Regressao do bug "o cachorro fica parado": os waypoints precisam cair no
## CENTRO da celula. AStarGrid2D.get_point_path devolvia o canto (celula *
## cell_size), meia celula fora do centro em cada eixo -- o waypoint caia em
## cima do canto de uma parede, o corpo do cachorro colidia e nunca chegava a
## tolerancia_de_chegada. Um caminho em corredor livre e o caso mais simples
## que expoe isso.
func teste_waypoints_caem_no_centro_da_celula() -> void:
	var solido: Array = [
		[false, false, false],
		[true, true, false],
		[false, false, false],
	]
	var labirinto: TileMapLayer = _construir_tilemap(solido, 3, 3)
	var navegacao := Navegacao.new()
	navegacao.configurar(labirinto)

	var caminho: PackedVector2Array = navegacao.calcular_caminho(
		labirinto.map_to_local(Vector2i(0, 0)), labirinto.map_to_local(Vector2i(2, 2)))

	if not afirmar_verdadeiro(caminho.size() > 0, "existe caminho pelo corredor livre"):
		labirinto.queue_free()
		return

	var fora_do_centro: PackedStringArray = PackedStringArray()
	for ponto: Vector2 in caminho:
		var celula: Vector2i = labirinto.local_to_map(labirinto.to_local(ponto))
		var centro: Vector2 = labirinto.to_global(labirinto.map_to_local(celula))
		if not ponto.is_equal_approx(centro):
			fora_do_centro.append("%s != centro %s" % [ponto, centro])
		if bool(solido[celula.y][celula.x]):
			fora_do_centro.append("waypoint %s cai em celula solida %s" % [ponto, celula])
	labirinto.queue_free()

	afirmar_igual(fora_do_centro.size(), 0,
		"todo waypoint no centro de uma celula livre: %s" % str(fora_do_centro))


func teste_destino_solido_nao_tem_caminho() -> void:
	var solido: Array = [
		[false, false],
		[false, true],
	]
	var labirinto: TileMapLayer = _construir_tilemap(solido, 2, 2)
	var navegacao := Navegacao.new()
	navegacao.configurar(labirinto)

	var caminho: PackedVector2Array = navegacao.calcular_caminho(
		labirinto.map_to_local(Vector2i(0, 0)), labirinto.map_to_local(Vector2i(1, 1)))
	labirinto.queue_free()

	afirmar_igual(caminho.size(), 0, "destino solido nao tem caminho, nao trava nem devolve lixo")


# ---------------------------------------------------------------------------
# Apoio
# ---------------------------------------------------------------------------

func _gerar_grade_solida(rng: RandomNumberGenerator, origem: Vector2i, destino: Vector2i) -> Array:
	var grade: Array = []
	for y: int in ALTURA:
		var linha: Array = []
		for x: int in LARGURA:
			linha.append(rng.randf() < DENSIDADE_SOLIDA)
		grade.append(linha)
	# Origem e destino nunca sao solidos -- a mesma garantia que
	# AStarReferencia.calcular e Navegacao.calcular_caminho fazem em runtime.
	grade[origem.y][origem.x] = false
	grade[destino.y][destino.x] = false
	return grade


## solido[y][x] == true vira o tile de parede (atlas 1,0); false vira piso (0,0)
## -- as mesmas coordenadas de recursos/tilesets/labirinto.tres.
func _construir_tilemap(solido: Array, largura: int, altura: int) -> TileMapLayer:
	var labirinto := TileMapLayer.new()
	labirinto.tile_set = _tileset
	for y: int in altura:
		for x: int in largura:
			var atlas: Vector2i = Vector2i(1, 0) if bool(solido[y][x]) else Vector2i(0, 0)
			labirinto.set_cell(Vector2i(x, y), 0, atlas)
	add_child(labirinto)
	return labirinto
