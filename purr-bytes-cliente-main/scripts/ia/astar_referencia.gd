class_name AStarReferencia
extends RefCounted

## Implementacao didatica do A* -- NAO roda em jogo nenhum. Quem roda em tempo
## real e scripts/ia/navegacao.gd, sobre o AStarGrid2D nativo do Godot. Esta
## classe existe por tres motivos (docs/decisoes/0001-astar.md):
##
##   a) gerar o pseudocodigo da monografia;
##   b) ser lida na defesa com fila de prioridade, g/h/f e conjuntos aberto e
##      fechado explicitos -- nada escondido dentro de uma classe da engine;
##   c) servir de oraculo nos testes: o CUSTO do caminho tem que bater com o do
##      AStarGrid2D em qualquer mapa (tests/teste_astar.gd), ou um dos dois
##      esta errado.
##
## Movimento em 4 direcoes, custo unitario por passo, heuristica de Manhattan.
## Manhattan nunca superestima a distancia real neste grid (admissivel) e a
## diferenca de heuristica entre celulas vizinhas nunca excede o custo da
## aresta que as liga, que e 1 (consistente). As duas propriedades juntas
## garantem que o primeiro caminho que o algoritmo fecha ate o destino ja e o
## de custo minimo -- e por isso o A* nao precisa reabrir nos ja fechados.

class Resultado:
	extends RefCounted
	var achou: bool = false
	var custo: float = 0.0
	var caminho: Array[Vector2i] = []


class _No:
	extends RefCounted
	var celula: Vector2i
	var g: float
	var f: float
	var veio_de: Vector2i

	func _init(celula_: Vector2i, g_: float, h_: float, veio_de_: Vector2i) -> void:
		celula = celula_
		g = g_
		f = g_ + h_
		veio_de = veio_de_


const _DIRECOES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## e_solido: Callable(Vector2i) -> bool. Recebe uma funcao em vez de amarrar
## este algoritmo a uma estrutura de mapa especifica -- o mesmo motivo pelo
## qual Navegacao le o TileMapLayer direto em vez de copiar para uma matriz.
static func calcular(
		e_solido: Callable, largura: int, altura: int, origem: Vector2i, destino: Vector2i) -> Resultado:
	var resultado := Resultado.new()

	if not _dentro_da_grade(origem, largura, altura) or not _dentro_da_grade(destino, largura, altura):
		return resultado
	if bool(e_solido.call(origem)) or bool(e_solido.call(destino)):
		return resultado

	# Conjunto aberto: nos descobertos, ainda nao expandidos. Busca linear pelo
	# menor f em vez de heap binario -- clareza didatica em vez de desempenho,
	# porque o papel de rodar rapido e do AStarGrid2D em navegacao.gd, nao
	# desta implementacao de referencia.
	var aberto: Dictionary = {}    # Vector2i -> _No
	var fechado: Dictionary = {}   # Vector2i -> _No

	aberto[origem] = _No.new(origem, 0.0, _heuristica_manhattan(origem, destino), origem)

	while not aberto.is_empty():
		var atual: Vector2i = _menor_f(aberto)
		var no_atual: _No = aberto[atual]

		if atual == destino:
			resultado.achou = true
			resultado.custo = no_atual.g
			resultado.caminho = _reconstruir_caminho(fechado, aberto, atual, origem)
			return resultado

		aberto.erase(atual)
		fechado[atual] = no_atual

		for direcao: Vector2i in _DIRECOES:
			var vizinho: Vector2i = atual + direcao
			if not _dentro_da_grade(vizinho, largura, altura):
				continue
			if fechado.has(vizinho) or bool(e_solido.call(vizinho)):
				continue

			var g_tentativo: float = no_atual.g + 1.0  # custo unitario por passo
			if aberto.has(vizinho) and (aberto[vizinho] as _No).g <= g_tentativo:
				continue  # caminho ja conhecido ate o vizinho e igual ou melhor

			aberto[vizinho] = _No.new(
				vizinho, g_tentativo, _heuristica_manhattan(vizinho, destino), atual)

	return resultado  # conjunto aberto esvaziou sem alcancar o destino: sem caminho


static func _heuristica_manhattan(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))


static func _menor_f(aberto: Dictionary) -> Vector2i:
	var melhor: Vector2i = aberto.keys()[0]
	var melhor_f: float = (aberto[melhor] as _No).f
	for celula: Vector2i in aberto:
		var f: float = (aberto[celula] as _No).f
		if f < melhor_f:
			melhor = celula
			melhor_f = f
	return melhor


static func _dentro_da_grade(celula: Vector2i, largura: int, altura: int) -> bool:
	return celula.x >= 0 and celula.x < largura and celula.y >= 0 and celula.y < altura


static func _reconstruir_caminho(
		fechado: Dictionary, aberto: Dictionary, destino: Vector2i, origem: Vector2i) -> Array[Vector2i]:
	var caminho: Array[Vector2i] = []
	var atual: Vector2i = destino
	while atual != origem:
		caminho.append(atual)
		var no: _No = fechado[atual] if fechado.has(atual) else (aberto[atual] as _No)
		atual = no.veio_de
	caminho.append(origem)
	caminho.reverse()
	return caminho
