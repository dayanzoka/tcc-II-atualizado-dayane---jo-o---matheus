class_name GeradorDeMapa
extends RefCounted

## Gera um MapaConfig SEMPRE SOLUCIONAVEL a partir de largura, altura e semente.
##
## "Sempre solucionavel" nao e promessa: e verificacao. O mapa so sai daqui
## depois de passar por MapaConfig.problemas(), o mesmo validador que a fase roda
## ao carregar -- jogador, porta, pacotes e cachorros todos alcancaveis, borda
## fechada, contagem batendo. Se por algum motivo nao passar, o gerador tenta a
## proxima semente em vez de devolver um labirinto quebrado.
##
## O traçado e um backtracker recursivo (labirinto perfeito: um caminho unico
## entre dois pontos quaisquer) seguido de BRAIDING -- abrir paredes para
## eliminar becos sem saida. Labirinto perfeito e ruim para este jogo: quem e
## perseguido fica encurralado no primeiro beco, e a fuga vira sorte. Com
## braiding surgem ciclos, e ai existe SEMPRE mais de uma rota -- e a diferenca
## entre o corredor linear e a sensacao de Pac-Man, onde dar a volta no
## perseguidor e uma decisao do jogador.

## Proporcao de becos sem saida que viram ciclo. 1.0 removeria todos e o mapa
## viraria uma sala aberta sem tensao; 0.0 devolveria o labirinto perfeito.
const _FRACAO_DE_BRAIDING: float = 0.75

const LARGURA_MINIMA: int = 9
const ALTURA_MINIMA: int = 9
const _MAXIMO_DE_TENTATIVAS: int = 12


class Resultado:
	extends RefCounted
	var mapa: MapaConfig = null
	var semente: int = 0
	var erros: PackedStringArray = PackedStringArray()

	func ok() -> bool:
		return mapa != null and erros.is_empty()


## semente <= 0 sorteia uma; qualquer outro valor e reproduzivel -- a mesma
## semente devolve o mesmo mapa, que e o que permite o professor guardar no
## JSON a fase que ele testou, e nao uma parecida.
static func gerar(largura: int, altura: int, semente: int,
		pacotes: int, cachorros: int) -> Resultado:

	var resultado := Resultado.new()
	var largura_util: int = _impar(maxi(LARGURA_MINIMA, largura))
	var altura_util: int = _impar(maxi(ALTURA_MINIMA, altura))

	var semente_base: int = semente
	if semente_base <= 0:
		semente_base = abs(int(Time.get_unix_time_from_system() * 1000.0)) % 2147483647
		semente_base = maxi(1, semente_base)

	for tentativa: int in _MAXIMO_DE_TENTATIVAS:
		var semente_atual: int = semente_base + tentativa
		var mapa: MapaConfig = _construir(largura_util, altura_util, semente_atual,
			pacotes, cachorros)
		if mapa == null:
			continue

		var problemas: PackedStringArray = mapa.problemas()
		if problemas.is_empty():
			resultado.mapa = mapa
			resultado.semente = semente_atual
			return resultado
		resultado.erros = problemas

	# Chegar aqui significa que nem doze sementes produziram mapa valido para as
	# medidas pedidas -- tipicamente area pequena demais para tantas entidades.
	if resultado.erros.is_empty():
		resultado.erros.append("nao foi possivel gerar um mapa %dx%d com %d pacote(s) e %d cachorro(s)"
			% [largura_util, altura_util, pacotes, cachorros])
	return resultado


static func _impar(valor: int) -> int:
	# O backtracker anda de duas em duas celulas: com medida par, a ultima linha
	# (ou coluna) ficaria sem ser escavada e viraria parede macica.
	return valor if valor % 2 == 1 else valor + 1


static func _construir(largura: int, altura: int, semente: int,
		pacotes: int, cachorros: int) -> MapaConfig:

	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var grade: Array = []
	for y: int in altura:
		var linha: Array = []
		for x: int in largura:
			linha.append(MapaConfig.PAREDE)
		grade.append(linha)

	_escavar(grade, Vector2i(1, 1), largura, altura, rng)
	_abrir_ciclos(grade, largura, altura, rng)

	var livres: Array[Vector2i] = []
	for y: int in altura:
		for x: int in largura:
			if grade[y][x] == MapaConfig.PISO:
				livres.append(Vector2i(x, y))

	# 2 = entrada e saida. Sem espaco para todo mundo, nao adianta seguir.
	if livres.size() < pacotes + cachorros + 2:
		return null

	var ocupadas: Array[Vector2i] = []
	var entrada: Vector2i = livres[0]
	ocupadas.append(entrada)

	# A saida e a celula mais longe da entrada: e o que garante que atravessar o
	# mapa seja o objetivo, em vez de a porta nascer ao lado do jogador.
	var saida: Vector2i = _mais_distante(livres, ocupadas)
	ocupadas.append(saida)

	# Pacotes e cachorros por dispersao gulosa: cada novo ponto e o que fica
	# mais longe de tudo que ja foi colocado, entao nada nasce empilhado.
	var celulas_de_pacote: Array[Vector2i] = []
	for _i: int in pacotes:
		var escolhida: Vector2i = _mais_distante(livres, ocupadas)
		celulas_de_pacote.append(escolhida)
		ocupadas.append(escolhida)

	var celulas_de_cachorro: Array[Vector2i] = []
	for _i: int in cachorros:
		var escolhida: Vector2i = _mais_distante(livres, ocupadas)
		celulas_de_cachorro.append(escolhida)
		ocupadas.append(escolhida)

	grade[entrada.y][entrada.x] = MapaConfig.JOGADOR
	grade[saida.y][saida.x] = MapaConfig.SAIDA
	for celula: Vector2i in celulas_de_pacote:
		grade[celula.y][celula.x] = MapaConfig.PACOTE
	for celula: Vector2i in celulas_de_cachorro:
		grade[celula.y][celula.x] = MapaConfig.CACHORRO

	var linhas := PackedStringArray()
	for y: int in altura:
		linhas.append("".join(PackedStringArray(grade[y])))

	var mapa := MapaConfig.new()
	mapa.linhas = linhas
	return mapa


## Backtracker iterativo (e nao recursivo): um labirinto 41x31 daria mais de 600
## niveis de recursao, e a pilha do GDScript nao e o lugar para isso.
static func _escavar(grade: Array, inicio: Vector2i, largura: int, altura: int,
		rng: RandomNumberGenerator) -> void:

	grade[inicio.y][inicio.x] = MapaConfig.PISO
	var pilha: Array[Vector2i] = [inicio]

	while not pilha.is_empty():
		var atual: Vector2i = pilha[pilha.size() - 1]
		var direcoes: Array[Vector2i] = [
			Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
		_embaralhar(direcoes, rng)

		var avancou: bool = false
		for direcao: Vector2i in direcoes:
			var vizinho: Vector2i = atual + direcao
			if vizinho.x < 1 or vizinho.y < 1 or vizinho.x > largura - 2 or vizinho.y > altura - 2:
				continue
			if grade[vizinho.y][vizinho.x] == MapaConfig.PISO:
				continue
			# Abre a parede ENTRE as duas celulas, e nao so a celula de destino.
			grade[atual.y + direcao.y / 2][atual.x + direcao.x / 2] = MapaConfig.PISO
			grade[vizinho.y][vizinho.x] = MapaConfig.PISO
			pilha.append(vizinho)
			avancou = true
			break

		if not avancou:
			pilha.pop_back()


## Braiding: para cada beco sem saida, abre uma parede vizinha e transforma o
## beco em passagem. E isto que tira o "corredor unico" e da ciclos ao mapa.
static func _abrir_ciclos(grade: Array, largura: int, altura: int,
		rng: RandomNumberGenerator) -> void:

	var becos: Array[Vector2i] = []
	for y: int in range(1, altura - 1):
		for x: int in range(1, largura - 1):
			if grade[y][x] != MapaConfig.PISO:
				continue
			if _vizinhos_livres(grade, Vector2i(x, y)) == 1:
				becos.append(Vector2i(x, y))

	_embaralhar_celulas(becos, rng)
	var alvo: int = int(float(becos.size()) * _FRACAO_DE_BRAIDING)

	for i: int in mini(alvo, becos.size()):
		var beco: Vector2i = becos[i]
		var candidatas: Array[Vector2i] = []
		for direcao: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var parede: Vector2i = beco + direcao
			var alem: Vector2i = beco + direcao * 2
			# So derruba parede que tenha piso do outro lado: abrir para a borda
			# externa furaria o mapa, e o validador (com razao) o reprovaria.
			if parede.x < 1 or parede.y < 1 or parede.x > largura - 2 or parede.y > altura - 2:
				continue
			if alem.x < 1 or alem.y < 1 or alem.x > largura - 2 or alem.y > altura - 2:
				continue
			if grade[parede.y][parede.x] == MapaConfig.PAREDE \
					and grade[alem.y][alem.x] == MapaConfig.PISO:
				candidatas.append(parede)

		if candidatas.is_empty():
			continue
		var escolhida: Vector2i = candidatas[rng.randi_range(0, candidatas.size() - 1)]
		grade[escolhida.y][escolhida.x] = MapaConfig.PISO


static func _vizinhos_livres(grade: Array, celula: Vector2i) -> int:
	var total: int = 0
	for direcao: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var vizinho: Vector2i = celula + direcao
		if vizinho.y >= 0 and vizinho.y < grade.size() \
				and vizinho.x >= 0 and vizinho.x < grade[vizinho.y].size() \
				and grade[vizinho.y][vizinho.x] == MapaConfig.PISO:
			total += 1
	return total


## Distancia de Manhattan ao ponto ocupado mais proximo, maximizada. Nao e
## distancia de caminho (que seria mais caro): para espalhar entidades pelo mapa
## a aproximacao basta, e o validador confere alcancabilidade de verdade depois.
static func _mais_distante(livres: Array[Vector2i], ocupadas: Array[Vector2i]) -> Vector2i:
	var melhor: Vector2i = livres[0]
	var melhor_custo: int = -1
	for celula: Vector2i in livres:
		if ocupadas.has(celula):
			continue
		var minimo: int = 1 << 30
		for ocupada: Vector2i in ocupadas:
			minimo = mini(minimo, absi(celula.x - ocupada.x) + absi(celula.y - ocupada.y))
		if minimo > melhor_custo:
			melhor_custo = minimo
			melhor = celula
	return melhor


## Fisher-Yates com o rng semeado. Array.shuffle() usaria o RNG global, e a
## mesma semente deixaria de devolver o mesmo mapa.
static func _embaralhar(itens: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i: int in range(itens.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var troca: Vector2i = itens[i]
		itens[i] = itens[j]
		itens[j] = troca


static func _embaralhar_celulas(itens: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	_embaralhar(itens, rng)
