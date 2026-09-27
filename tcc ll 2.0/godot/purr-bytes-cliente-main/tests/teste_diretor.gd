extends CasoDeTeste

## Critérios de aceite do Marco 2 (seção 7 do CLAUDE.md):
##   - dado um roteiro de pistas, a região-alvo escolhida é determinística e
##     reproduzível
##   - o cachorro (aqui, a crença do Diretor) nunca converge para o jogador
##     sem pista nem linha de visão
##
## Diretor não recebe posição nenhuma nestes testes -- só os nós Area2D das
## regiões (que nem precisam estar numa SceneTree: global_position funciona
## sem parent, e é a única coisa que o Diretor lê deles).

var _regiao_a: Area2D
var _regiao_b: Area2D
var _regiao_c: Area2D
var _regioes: Array[Area2D]


func antes() -> void:
	_regiao_a = Area2D.new()
	_regiao_a.position = Vector2(0, 0)
	_regiao_b = Area2D.new()
	_regiao_b.position = Vector2(100, 0)
	_regiao_c = Area2D.new()
	_regiao_c.position = Vector2(200, 0)
	_regioes = [_regiao_a, _regiao_b, _regiao_c]


func depois() -> void:
	_regiao_a.free()
	_regiao_b.free()
	_regiao_c.free()


func _diretor(peso_forte: float = 1.0, peso_fraco: float = 0.25,
		peso_captura: float = 2.0, decaimento_por_s: float = 0.1) -> Diretor:
	return Diretor.new(_regioes, peso_forte, peso_fraco, peso_captura, decaimento_por_s)


func teste_sem_pista_nenhuma_crenca_e_uniforme_e_nao_aponta_para_o_jogador() -> void:
	var diretor: Diretor = _diretor()
	# Sem pista, todas as regioes comecam igualmente prováveis -- a escolha da
	# "mais provável" cai no desempate (primeira da lista), não em qualquer
	# noção de onde o jogador esteja de verdade.
	for regiao: Area2D in _regioes:
		afirmar_proximo(diretor.crenca_da_regiao(regiao), 1.0 / 3.0, 0.0001,
			"crenca uniforme sem pista nenhuma")
	afirmar_igual(diretor.regiao_mais_provavel(), _regiao_a, "desempate cai na primeira regiao")


func teste_pista_forte_muda_o_alvo_de_forma_deterministica() -> void:
	var diretor: Diretor = _diretor()
	diretor.pista_comando_errado(_regiao_b)
	afirmar_igual(diretor.regiao_mais_provavel(), _regiao_b,
		"uma pista forte ja basta para a regiao B liderar")
	afirmar_igual(diretor.alvo_atual(), _regiao_b.global_position,
		"o alvo e o centro da regiao, nunca uma posicao do jogador")


func teste_mesmo_roteiro_de_pistas_produz_sempre_o_mesmo_alvo() -> void:
	# Determinismo: dois Diretores frescos, mesmo roteiro, mesmo resultado --
	# nao ha aleatoriedade nenhuma na crenca (ver ADR 0002), entao nao precisa
	# de semente para ser reproduzivel.
	var roteiro: Array = [
		["movimento", _regiao_a], ["movimento", _regiao_a],
		["comando_errado", _regiao_c], ["movimento", _regiao_b],
	]

	var alvos_1: Array[Area2D] = _rodar_roteiro(_diretor(), roteiro)
	var alvos_2: Array[Area2D] = _rodar_roteiro(_diretor(), roteiro)

	afirmar_igual(alvos_1.size(), alvos_2.size(), "mesmo numero de transicoes de alvo")
	for i: int in alvos_1.size():
		afirmar_igual(alvos_1[i], alvos_2[i], "alvo %d identico nas duas execucoes" % i)


func teste_pista_captura_pesa_mais_que_movimento() -> void:
	var diretor: Diretor = _diretor()
	diretor.pista_movimento(_regiao_a)
	var crenca_apos_movimento: float = diretor.crenca_da_regiao(_regiao_a)

	var diretor2: Diretor = _diretor()
	diretor2.pista_captura(_regiao_a)
	var crenca_apos_captura: float = diretor2.crenca_da_regiao(_regiao_a)

	afirmar_verdadeiro(crenca_apos_captura > crenca_apos_movimento,
		"captura reforca a crenca mais que um simples movimento observado")


func teste_decaimento_relaxa_a_crenca_de_volta_ao_uniforme() -> void:
	var diretor: Diretor = _diretor()
	diretor.pista_comando_errado(_regiao_b)
	afirmar_igual(diretor.regiao_mais_provavel(), _regiao_b, "regiao B lidera apos a pista")

	# delta grande o bastante para o fator de decaimento saturar em 1.0 --
	# a crenca some para uniforme numa unica chamada, de proposito
	# deterministico (sem precisar simular N quadros pequenos no teste).
	diretor.decair(1000.0)

	for regiao: Area2D in _regioes:
		afirmar_proximo(diretor.crenca_da_regiao(regiao), 1.0 / 3.0, 0.0001,
			"decaimento total volta para a distribuicao uniforme")
	afirmar_igual(diretor.regiao_mais_provavel(), _regiao_a,
		"sem pista recente, o alvo volta a cair no desempate -- nao fica preso na ultima pista")


func teste_regiao_desconhecida_e_ignorada_sem_erro() -> void:
	var diretor: Diretor = _diretor()
	var regiao_estranha := Area2D.new()
	diretor.pista_comando_errado(regiao_estranha)  # nao pertence a _regioes
	afirmar_igual(diretor.regiao_mais_provavel(), _regiao_a,
		"pista de regiao fora do conjunto conhecido nao altera a crenca")
	regiao_estranha.free()


func teste_sinal_alvo_alterado_so_emite_na_transicao() -> void:
	var diretor: Diretor = _diretor()
	var transicoes: Array[Area2D] = []
	diretor.alvo_alterado.connect(func(r: Area2D) -> void: transicoes.append(r))

	diretor.pista_movimento(_regiao_a)  # regiao A ja era a lider (desempate) -- sem transicao
	afirmar_tamanho(transicoes, 0, "reforcar quem ja lidera nao emite alvo_alterado")

	diretor.pista_comando_errado(_regiao_c)  # agora C assume a lideranca
	afirmar_tamanho(transicoes, 1, "trocar de lider emite alvo_alterado uma vez")
	afirmar_igual(transicoes[0], _regiao_c, "emite a nova regiao lider")


func _rodar_roteiro(diretor: Diretor, roteiro: Array) -> Array[Area2D]:
	var alvos: Array[Area2D] = []
	diretor.alvo_alterado.connect(func(r: Area2D) -> void: alvos.append(r))
	for passo: Array in roteiro:
		var tipo: String = passo[0]
		var regiao: Area2D = passo[1]
		match tipo:
			"movimento":
				diretor.pista_movimento(regiao)
			"comando_errado":
				diretor.pista_comando_errado(regiao)
			"captura":
				diretor.pista_captura(regiao)
	return alvos
