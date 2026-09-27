class_name PacoteConfig
extends Resource

## Um pacote de dados espalhado pelo labirinto -- dado puro.
##
## Encostar no pacote nao coleta: abre uma pergunta curta sobre qual ferramenta
## criptografica serve para aquele caso (cenas/base/caixa_puzzle.tscn). E a
## unica parte do jogo em que o conhecimento e cobrado FORA do terminal, e de
## proposito: o terminal mede se o jogador sabe operar a cifra, o pacote mede se
## ele sabe ESCOLHER a cifra -- que e a competencia que a monografia mede no
## pre/pos-teste.
##
## No modo de treino (ConfigJogo.modo_treino) a caixa nao abre e o pacote e
## coletado ao encostar: ler enunciado e clicar botao e tarefa de humano.

@export var identificador: String = "pacote"

## Celula do labirinto (coordenada de TileMapLayer), como em CachorroConfig.
@export var celula: Vector2i = Vector2i(1, 1)

@export_multiline var enunciado: String = ""

## Arquetipo da pergunta. Nao e enfeite: ele decide o QUE sao as opcoes.
##
##   APLICACAO    -- "qual ferramenta protege deste vigia?": as opcoes sao
##                   codigos de algoritmo, exibidos como texto (nome do
##                   algoritmo, via LegendaCores.nome()) -- NUNCA como cor.
##                   Cor e identidade visual do cachorro na cena, nao pista de
##                   resposta; o enunciado tem que ser respondivel sem ela
##                   (ver caixa_puzzle.gd e docs/conformidade-monografia.md).
##   CONCEITO     -- "o que essa ferramenta faz com cada letra?": as opcoes sao
##                   frases. Ensina o mecanismo.
##   DISCERNIMENTO -- "qual destas NAO serve para X?": tambem frases. Ensina
##                   limite e comparacao (e onde mora a diferenca cifra x hash).
##
## Uma fase mistura os tres de proposito: so APLICACAO ensinaria o jogador a
## decorar um rotulo sem entender o que ele significa.
@export_enum("APLICACAO", "CONCEITO", "DISCERNIMENTO") var tipo: String = "APLICACAO"

## Opcoes oferecidas. Em APLICACAO sao codigos de algoritmo (os mesmos de
## LegendaCores), exibidos como botao de texto com o nome do algoritmo -- nunca
## colorido (ver caixa_puzzle.gd). Nos outros tipos sao frases curtas, exibidas
## como estao -- misturar conceito e nome de algoritmo nas opcoes da MESMA
## pergunta so confundiria quem ainda esta aprendendo a diferenca.
@export var opcoes: PackedStringArray = ["CESAR", "VIGENERE", "SHA256"]

@export var resposta_correta: String = "CESAR"

## Frase curta mostrada ao acertar. E onde a licao fica explicita -- errar e
## acertar sem entender o porque nao ensina nada.
@export_multiline var explicacao_correta: String = ""

@export_range(0, 1000, 5) var pontos_acerto: int = 60
@export_range(0, 1000, 5) var penalidade_erro: int = 20


func problemas() -> PackedStringArray:
	var lista := PackedStringArray()
	if identificador.strip_edges().is_empty():
		lista.append("pacote sem identificador")
	if identificador.length() > 60:
		lista.append("identificador de pacote '%s' excede 60 caracteres (tentativa_comando.desafio)"
			% identificador)
	if enunciado.strip_edges().is_empty():
		lista.append("pacote '%s' sem enunciado" % identificador)
	if opcoes.size() < 2:
		lista.append("pacote '%s' precisa de ao menos duas opcoes" % identificador)
	if not opcoes.has(resposta_correta):
		lista.append("pacote '%s': a resposta correta '%s' nao esta entre as opcoes"
			% [identificador, resposta_correta])
	if opcoes_de_algoritmo():
		for opcao: String in opcoes:
			if not LegendaCores.conhece(opcao):
				lista.append("pacote '%s' e de APLICACAO, entao a opcao '%s' precisa ser um "
					% [identificador, opcao] + "algoritmo conhecido")

		# Regra 3 do banco de perguntas, virada em validacao: se o enunciado cita
		# o nome da ferramenta que e a resposta, a pergunta se responde sozinha e
		# nao mede nada. Como o enunciado descreve a AMEACA (a cor) e a resposta
		# e a ferramenta, isso e sempre erro de redacao -- e agora reprova a fase
		# em vez de depender de alguem reparar na revisao.
		var minusculo: String = enunciado.to_lower()
		for termo: String in [resposta_correta.to_lower(), LegendaCores.nome(resposta_correta).to_lower()]:
			if not termo.is_empty() and minusculo.contains(termo):
				lista.append("pacote '%s': o enunciado cita '%s', que e a propria resposta"
					% [identificador, termo])
				break
	else:
		for opcao: String in opcoes:
			if opcao.strip_edges().is_empty():
				lista.append("pacote '%s' tem opcao vazia" % identificador)
			elif LegendaCores.conhece(opcao):
				lista.append(("pacote '%s' e de %s, entao as opcoes sao frases -- '%s' e nome "
					+ "de algoritmo e pertence a uma pergunta de APLICACAO")
					% [identificador, tipo, opcao])

	return lista


## Em APLICACAO as opcoes sao algoritmos (botao colorido, nome vindo da
## legenda); nos demais tipos sao frases exibidas como estao.
func opcoes_de_algoritmo() -> bool:
	return tipo == "APLICACAO"
