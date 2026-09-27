class_name MapaConfig
extends Resource

## O labirinto de uma fase, escrito como texto.
##
## COMO CRIAR UM MAPA NOVO
##
## 1. Escreva um retangulo de linhas do mesmo comprimento, cercado de parede:
##
##        #########
##        #..P..o.#
##        #.###.#.#
##        #.o.#...#
##        #.#.###.#
##        #...D..S#
##        #########
##
## 2. Legenda:
##        #  parede          .  caminho livre
##        P  onde o jogador comeca (exatamente um)
##        S  a porta de saida     (exatamente uma)
##        o  um pacote de dados   (um por PacoteConfig da fase, na ordem de leitura)
##        D  um cachorro          (um por CachorroConfig da fase, na ordem de leitura)
##
## 3. Atribua este recurso a FaseConfig.mapa e rode
##    tools/gerar_fase_0N.gd. Se algo estiver incoerente, problemas() diz o que
##    e a fase se recusa a rodar -- em vez de abrir um labirinto quebrado.
##
## POR QUE TEXTO, E NAO O DESENHO DO TileMapLayer
##
## Antes, o labirinto so existia pintado dentro do .tscn, e a navegacao tratava
## celula NAO PINTADA como parede (Navegacao._e_solido). Um tile esquecido no
## editor virava, entao, parede invisivel: cachorro preso, pacote inalcancavel,
## porta impossivel -- tudo sem uma linha de erro. Em texto, o mesmo mapa cabe
## num diff, se le de uma vez e passa por um validador antes de virar jogo.
##
## O TileMapLayer continua existindo e continua sendo o que a colisao e o
## AStarGrid2D leem -- mas agora ele e DERIVADO deste texto (FaseBase o repinta
## no _ready), e nao uma segunda fonte de verdade que pode divergir.

const PAREDE: String = "#"
const PISO: String = "."
const JOGADOR: String = "P"
const PACOTE: String = "o"
const CACHORRO: String = "D"
const SAIDA: String = "S"

## Coordenadas de atlas em recursos/tilesets/labirinto.tres. Piso e parede sao
## os dois unicos tiles do conjunto; "solido" mora no custom data layer do
## proprio tile, entao pintar por aqui ja define colisao e navegacao juntas.
const ATLAS_PISO: Vector2i = Vector2i(0, 0)
const ATLAS_PAREDE: Vector2i = Vector2i(1, 0)

const _ANDAVEIS: PackedStringArray = [PISO, JOGADOR, PACOTE, CACHORRO, SAIDA]

@export var linhas: PackedStringArray = PackedStringArray()


func largura() -> int:
	return linhas[0].length() if not linhas.is_empty() else 0


func altura() -> int:
	return linhas.size()


func dentro(celula: Vector2i) -> bool:
	return celula.y >= 0 and celula.y < altura() \
		and celula.x >= 0 and celula.x < linhas[celula.y].length()


func caractere(celula: Vector2i) -> String:
	return linhas[celula.y][celula.x] if dentro(celula) else ""


## Andavel = qualquer coisa que nao seja parede. Jogador, pacote, cachorro e
## saida ficam POR CIMA do piso: eles marcam uma posicao, nao um tipo de chao.
func e_andavel(celula: Vector2i) -> bool:
	return _ANDAVEIS.has(caractere(celula))


## Todas as celulas com um dado marcador, em ordem de leitura (linha a linha,
## da esquerda para a direita). E essa ordem que pareia os 'o' do desenho com
## FaseConfig.pacotes e os 'D' com FaseConfig.cachorros -- o primeiro 'o' do
## texto e o primeiro pacote da lista.
func celulas_de(marcador: String) -> Array[Vector2i]:
	var encontradas: Array[Vector2i] = []
	for y: int in linhas.size():
		var linha: String = linhas[y]
		for x: int in linha.length():
			if linha[x] == marcador:
				encontradas.append(Vector2i(x, y))
	return encontradas


func celula_unica(marcador: String) -> Vector2i:
	var encontradas: Array[Vector2i] = celulas_de(marcador)
	return encontradas[0] if not encontradas.is_empty() else Vector2i(-1, -1)


## Inundacao a partir de uma celula, em 4 direcoes -- as mesmas do
## AStarGrid2D (DIAGONAL_MODE_NEVER). O conjunto devolvido e exatamente o que o
## jogador consegue alcancar andando; e contra ele que problemas() confere
## pacote, porta e cachorro.
func alcancaveis_a_partir_de(origem: Vector2i) -> Dictionary:
	var vistos: Dictionary = {}
	if not e_andavel(origem):
		return vistos

	var fila: Array[Vector2i] = [origem]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_back()
		if vistos.has(atual):
			continue
		vistos[atual] = true
		for direcao: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var vizinho: Vector2i = atual + direcao
			if e_andavel(vizinho) and not vistos.has(vizinho):
				fila.append(vizinho)
	return vistos


## Pinta o mapa numa TileMapLayer. Chamado por FaseBase no _ready e pelos
## geradores em tools/ -- os dois usam ESTE metodo, entao o que o editor mostra
## e o que o jogo carrega nao tem como divergir.
func pintar(camada: TileMapLayer) -> void:
	camada.clear()
	for y: int in linhas.size():
		var linha: String = linhas[y]
		for x: int in linha.length():
			var atlas: Vector2i = ATLAS_PAREDE if linha[x] == PAREDE else ATLAS_PISO
			camada.set_cell(Vector2i(x, y), 0, atlas)


## Tudo o que impede este mapa de virar uma fase jogavel.
##
## Recebe o FaseConfig para conferir as CONTAGENS: um 'o' a mais no desenho do
## que pacotes na lista significaria um pacote sem pergunta, e um a menos, uma
## pergunta que nunca aparece. Os dois sao bugs silenciosos hoje.
func problemas(config: FaseConfig = null) -> PackedStringArray:
	var lista := PackedStringArray()

	if linhas.is_empty():
		lista.append("mapa vazio")
		return lista

	# Retangulo: linha mais curta viraria coluna faltando, e celula faltando
	# conta como parede na navegacao -- exatamente o bug silencioso que este
	# validador existe para acabar.
	var comprimento: int = linhas[0].length()
	for y: int in linhas.size():
		if linhas[y].length() != comprimento:
			lista.append("linha %d tem %d caracteres; as outras tem %d"
				% [y, linhas[y].length(), comprimento])

	var validos := PackedStringArray([PAREDE, PISO, JOGADOR, PACOTE, CACHORRO, SAIDA])
	for y: int in linhas.size():
		for x: int in linhas[y].length():
			var simbolo: String = linhas[y][x]
			if not validos.has(simbolo):
				lista.append("caractere '%s' desconhecido em (%d,%d); use um de %s"
					% [simbolo, x, y, " ".join(validos)])

	if not lista.is_empty():
		# Sem um retangulo bem formado, as checagens abaixo dariam mensagens
		# derivadas do primeiro erro e esconderiam a causa.
		return lista

	# Borda fechada: um buraco na parede externa deixa o jogador (e o A*) sair
	# do mapa, onde nao ha tile nenhum.
	for x: int in comprimento:
		if e_andavel(Vector2i(x, 0)) or e_andavel(Vector2i(x, altura() - 1)):
			lista.append("a borda do mapa esta aberta na coluna %d" % x)
			break
	for y: int in altura():
		if e_andavel(Vector2i(0, y)) or e_andavel(Vector2i(comprimento - 1, y)):
			lista.append("a borda do mapa esta aberta na linha %d" % y)
			break

	var jogadores: Array[Vector2i] = celulas_de(JOGADOR)
	var saidas: Array[Vector2i] = celulas_de(SAIDA)
	if jogadores.size() != 1:
		lista.append("o mapa precisa de exatamente um '%s' (inicio do jogador); achei %d"
			% [JOGADOR, jogadores.size()])
	if saidas.size() != 1:
		lista.append("o mapa precisa de exatamente um '%s' (porta de saida); achei %d"
			% [SAIDA, saidas.size()])

	var pacotes: Array[Vector2i] = celulas_de(PACOTE)
	var cachorros: Array[Vector2i] = celulas_de(CACHORRO)
	if config != null:
		if pacotes.size() != config.pacotes.size():
			lista.append("o mapa tem %d '%s' mas a fase declara %d pacotes"
				% [pacotes.size(), PACOTE, config.pacotes.size()])
		if cachorros.size() != config.cachorros.size():
			lista.append("o mapa tem %d '%s' mas a fase declara %d cachorros"
				% [cachorros.size(), CACHORRO, config.cachorros.size()])

	if jogadores.is_empty():
		return lista

	# Alcancabilidade: e aqui que "porta impossivel" e "pacote ilhado" deixam
	# de ser descoberta em playtest e viram erro de carga.
	var alcancaveis: Dictionary = alcancaveis_a_partir_de(jogadores[0])
	for celula: Vector2i in saidas:
		if not alcancaveis.has(celula):
			lista.append("a porta em (%d,%d) e inalcancavel a partir do inicio do jogador"
				% [celula.x, celula.y])
	for i: int in pacotes.size():
		if not alcancaveis.has(pacotes[i]):
			lista.append("o pacote %d, em (%d,%d), e inalcancavel a partir do inicio do jogador"
				% [i + 1, pacotes[i].x, pacotes[i].y])

	for i: int in cachorros.size():
		var celula: Vector2i = cachorros[i]
		var tem_vizinho: bool = false
		for direcao: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if e_andavel(celula + direcao):
				tem_vizinho = true
				break
		if not tem_vizinho:
			lista.append("o cachorro %d nasce preso em (%d,%d): nenhuma celula vizinha e andavel"
				% [i + 1, celula.x, celula.y])
		elif not alcancaveis.has(celula):
			# Cachorro numa area isolada nunca encontra o jogador: a ameaca
			# existe no desenho e nao existe no jogo.
			lista.append("o cachorro %d, em (%d,%d), esta numa area separada da do jogador"
				% [i + 1, celula.x, celula.y])

		if config == null or i >= config.cachorros.size():
			continue
		var config_do_cachorro: CachorroConfig = config.cachorros[i]
		if config_do_cachorro == null:
			continue
		for ancora: Vector2i in config_do_cachorro.ancoras:
			if not e_andavel(ancora):
				lista.append("a ancora (%d,%d) do cachorro '%s' cai em parede"
					% [ancora.x, ancora.y, config_do_cachorro.identificador])
			elif not alcancaveis.has(ancora):
				lista.append("a ancora (%d,%d) do cachorro '%s' e inalcancavel"
					% [ancora.x, ancora.y, config_do_cachorro.identificador])

	return lista
