class_name ApoioFaseDeTeste
extends RefCounted

## Fixture de FaseConfig para testes de integracao, desde que as fases fixas
## do TCC (fase_01/02/03) sairam do projeto (ADR 0012: o jogo virou
## ferramenta de autoria).
##
## Constroi em memoria uma fase na MESMA forma que os testes antigos
## carregavam de cenas/fases/fase_01.tscn (dois cachorros de Cesar com rota
## de patrulha, tres pacotes, um desafio de terminal) -- so que sem nenhum
## .tscn/.tres publicado: o mapa vem do MESMO GeradorDeMapa que uma fase de
## autoria usa, e cachorros/pacotes/desafio sao os mesmos Resource que
## FaseConfig sempre aceitou. Nao ha fase fixa nova aqui, so um fixture de
## teste que nunca sai de user://testes nem aparece em user://fases.

const CAMINHO_FASE_BASE: String = "res://cenas/base/fase_base.tscn"


## Cesar puro: a mesma forma da antiga fase_01.tscn, para os testes que
## precisam de um cachorro so enganavel por cifra (nao por comando livre, como
## as fases de autoria) e de um desafio de terminal de verdade.
static func config_cesar(semente: int = 909001) -> FaseConfig:
	var config := FaseConfig.new()
	config.numero = 1
	config.id_fase = Identificador.uuid_v4()
	config.titulo = "fase de teste (Cesar)"
	config.algoritmo = "CESAR"
	config.verbos_permitidos = PackedStringArray(["cifrar", "decifrar", "dica", "status"])
	config.vidas_iniciais = 3
	config.faixa_chave_minima = 1
	config.faixa_chave_maxima = 25

	var desafio := DesafioConfig.new()
	desafio.identificador = "teste-cesar-01"
	desafio.enunciado = "cifrar pacote chave=3"
	desafio.texto_claro = "pacote"
	desafio.chave_esperada = "3"
	desafio.verbo_esperado = "cifrar"
	config.desafios = [desafio]

	var cachorro_a := CachorroConfig.new()
	cachorro_a.identificador = "teste-cesar-a"
	cachorro_a.algoritmo_exigido = "CESAR"
	cachorro_a.ancoras = [Vector2i(3, 3), Vector2i(7, 3), Vector2i(7, 7), Vector2i(3, 7)]

	var cachorro_b := CachorroConfig.new()
	cachorro_b.identificador = "teste-cesar-b"
	cachorro_b.algoritmo_exigido = "CESAR"
	cachorro_b.ancoras = [Vector2i(5, 5), Vector2i(9, 5), Vector2i(9, 9), Vector2i(5, 9)]

	config.cachorros = [cachorro_a, cachorro_b]
	config.pacotes = _pacotes_de_teste()

	var gerado: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(
		21, 15, semente, config.pacotes.size(), config.cachorros.size())
	if gerado.ok():
		config.mapa = gerado.mapa
		config.semente_do_mapa = gerado.semente

	return config


## Tres pacotes com tipos e respostas distintas -- a mesma regra que
## PacoteConfig.problemas() cobra de uma fase real (nao misturar so
## "aplicacao", senao o jogador decoraria posicao em vez de conteudo).
static func _pacotes_de_teste() -> Array[PacoteConfig]:
	var a := PacoteConfig.new()
	a.identificador = "teste-pacote-a"
	a.tipo = "CONCEITO"
	a.enunciado = "pergunta de teste a"
	a.opcoes = PackedStringArray(["um", "dois", "tres"])
	a.resposta_correta = "um"

	var b := PacoteConfig.new()
	b.identificador = "teste-pacote-b"
	b.tipo = "CONCEITO"
	b.enunciado = "pergunta de teste b"
	b.opcoes = PackedStringArray(["quatro", "cinco", "seis"])
	b.resposta_correta = "cinco"

	var c := PacoteConfig.new()
	c.identificador = "teste-pacote-c"
	c.tipo = "DISCERNIMENTO"
	c.enunciado = "pergunta de teste c"
	c.opcoes = PackedStringArray(["sete", "oito", "nove"])
	c.resposta_correta = "oito"

	return [a, b, c]


## So instancia e atribui o config -- NAO adiciona a arvore, para quem chamar
## poder injetar regioes de Diretor (ver adicionar_regioes) antes do _ready()
## rodar. Quem chama e responsavel por add_child().
static func instanciar(config: FaseConfig) -> FaseBase:
	var cena: PackedScene = load(CAMINHO_FASE_BASE) as PackedScene
	var fase: FaseBase = cena.instantiate() as FaseBase
	fase.configuracao = config
	return fase


## Regioes de Diretor (Marco 2), do jeito que uma fase de autoria por script
## (tools/gerar_fase_0N.gd, quando existiam) as declarava na cena: Area2D como
## filhas de Marcadores/Regioes. Funciona porque instantiate() ja constroi a
## arvore de nos inteira -- so o _ready() (e com ele, FaseBase.
## _configurar_diretor(), que le regioes_no.get_children()) fica pendente ate
## a fase entrar na SceneTree. Chamar isto DEPOIS de add_child(fase) seria
## tarde demais: o Diretor ja teria decidido que a fase nao tem regiao nenhuma.
static func adicionar_regioes(fase: FaseBase, pontos: Array[Vector2]) -> void:
	var regioes_no: Node2D = fase.get_node("Marcadores/Regioes") as Node2D
	for i: int in pontos.size():
		var regiao := Area2D.new()
		regiao.name = "RegiaoDeTeste%d" % i
		regiao.position = pontos[i]
		regioes_no.add_child(regiao)
