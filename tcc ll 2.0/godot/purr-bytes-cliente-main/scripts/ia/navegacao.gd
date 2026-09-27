class_name Navegacao
extends RefCounted

## Wrapper fino sobre AStarGrid2D -- ferramenta nativa da secao 2 do CLAUDE.md
## para pathfinding em grade, entao nao ha razao para reimplementar busca em
## grafo aqui. A unica reimplementacao deliberada do projeto e
## scripts/ia/astar_referencia.gd, que nao roda em jogo nenhum (docs/decisoes/0001-astar.md).
##
## region vem de TileMapLayer.get_used_rect(), cell_size do TileSet, 4 direcoes
## (DIAGONAL_MODE_NEVER) e heuristica de Manhattan -- exatamente como a secao 6
## do CLAUDE.md pede, e pelo mesmo motivo do oraculo didatico: admissivel e
## consistente aqui, entao o caminho devolvido e sempre de custo minimo.
##
## Quem le "solido" e este wrapper, no TileData da mesma TileMapLayer que a
## colisao fisica usa (recursos/tilesets/labirinto.tres) -- mapa e navegacao
## sao o mesmo dado, nunca uma tabela paralela para desalinhar.

var _grade: AStarGrid2D = AStarGrid2D.new()
var _labirinto: TileMapLayer = null
var _indice_camada_solido: int = -1


func configurar(labirinto: TileMapLayer) -> void:
	_labirinto = labirinto
	var conjunto: TileSet = labirinto.tile_set
	_indice_camada_solido = _indice_da_camada_solido(conjunto)

	var regiao: Rect2i = labirinto.get_used_rect()
	_grade.region = regiao
	_grade.cell_size = Vector2(conjunto.tile_size)
	_grade.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grade.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grade.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grade.update()

	for y: int in range(regiao.position.y, regiao.position.y + regiao.size.y):
		for x: int in range(regiao.position.x, regiao.position.x + regiao.size.x):
			var celula := Vector2i(x, y)
			_grade.set_point_solid(celula, _e_solido(celula))


## Caminho em coordenadas de MUNDO, pronto para Cachorro.definir_caminho().
## Vazio se origem/destino cairem fora da grade, o destino for solido, ou nao
## houver caminho -- Cachorro.parar() ja trata caminho vazio como "ficar parado".
func calcular_caminho(origem_mundo: Vector2, destino_mundo: Vector2) -> PackedVector2Array:
	if _labirinto == null:
		return PackedVector2Array()

	var celula_origem: Vector2i = _labirinto.local_to_map(_labirinto.to_local(origem_mundo))
	var celula_destino: Vector2i = _labirinto.local_to_map(_labirinto.to_local(destino_mundo))

	if not _grade.is_in_boundsv(celula_origem) or not _grade.is_in_boundsv(celula_destino):
		return PackedVector2Array()
	if _grade.is_point_solid(celula_destino):
		return PackedVector2Array()

	# get_id_path (celulas), e nao get_point_path (pontos): AStarGrid2D coloca o
	# ponto de uma celula no CANTO dela (celula * cell_size + offset, com offset
	# zero por padrao), enquanto TileMapLayer.map_to_local devolve o CENTRO
	# (celula * tile_size + tile_size/2). A diferenca e meia celula na diagonal,
	# o que punha cada waypoint em cima do canto de uma parede: o corpo do
	# cachorro (10x10 num tile de 16) colidia, move_and_slide deslizava e ele
	# nunca chegava a tolerancia_de_chegada -- o cachorro travava no primeiro
	# waypoint. Converter celula por celula com map_to_local elimina a classe
	# inteira do problema, sem depender de acertar o offset da grade.
	var caminho_em_celulas: Array[Vector2i] = _grade.get_id_path(celula_origem, celula_destino)
	var caminho_mundo := PackedVector2Array()
	for celula: Vector2i in caminho_em_celulas:
		caminho_mundo.append(_labirinto.to_global(_labirinto.map_to_local(celula)))
	return caminho_mundo


## O ponto andavel mais proximo de um ponto qualquer do mundo, em coordenada de
## mundo. Devolve o proprio ponto quando ele ja esta em celula livre.
##
## Existe por causa de um travamento real: o Diretor publica o CENTRO de uma
## regiao e fase_base.gd varre alguns pontos ao redor dele (+-1 celula). Nada
## garantia que esses pontos caissem em piso -- e quando caiam em parede,
## calcular_caminho devolvia vazio, o cachorro parava, e o indice da varredura
## so avancava quando ele CHEGASSE ao ponto, o que nunca aconteceria. O
## cachorro travava de vez, e so nas fases com Diretor (2 e 3).
##
## A busca e em largura a partir da celula pedida, entao o resultado e sempre a
## celula livre mais proxima em numero de passos -- nao um chute de direcao.
func ponto_andavel_mais_proximo(ponto_mundo: Vector2) -> Vector2:
	if _labirinto == null:
		return ponto_mundo

	var celula: Vector2i = _labirinto.local_to_map(_labirinto.to_local(ponto_mundo))
	if _grade.is_in_boundsv(celula) and not _grade.is_point_solid(celula):
		return ponto_mundo

	var vistos: Dictionary = {celula: true}
	var fila: Array[Vector2i] = [celula]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_front()
		if _grade.is_in_boundsv(atual) and not _grade.is_point_solid(atual):
			return _labirinto.to_global(_labirinto.map_to_local(atual))
		for direcao: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var vizinho: Vector2i = atual + direcao
			if vistos.has(vizinho) or not _grade.is_in_boundsv(vizinho):
				continue
			vistos[vizinho] = true
			fila.append(vizinho)

	# Grade inteiramente solida: nao ha para onde mandar ninguem.
	return ponto_mundo


## Se um ponto do mundo cai em celula livre. Usado pelos testes e pela
## depuracao; a decisao de runtime passa por ponto_andavel_mais_proximo.
func ponto_e_andavel(ponto_mundo: Vector2) -> bool:
	if _labirinto == null:
		return false
	var celula: Vector2i = _labirinto.local_to_map(_labirinto.to_local(ponto_mundo))
	return _grade.is_in_boundsv(celula) and not _grade.is_point_solid(celula)


func _e_solido(celula: Vector2i) -> bool:
	var dados: TileData = _labirinto.get_cell_tile_data(celula)
	if dados == null:
		# Fora do que foi pintado no labirinto: nao andavel, e nao vazio.
		return true
	if _indice_camada_solido < 0:
		return false
	return bool(dados.get_custom_data_by_layer_id(_indice_camada_solido))


func _indice_da_camada_solido(conjunto: TileSet) -> int:
	for i: int in conjunto.get_custom_data_layers_count():
		if conjunto.get_custom_data_layer_name(i) == "solido":
			return i
	return -1
