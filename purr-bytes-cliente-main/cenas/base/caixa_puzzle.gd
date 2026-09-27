class_name CaixaPuzzle
extends CanvasLayer

## A caixinha que abre ao chegar num pacote: um enunciado curto e um botao por
## opcao, na cor do algoritmo.
##
## Botao em vez de campo de texto de proposito. O terminal ja mede digitacao
## (tempo_resposta_ms, erro lexico, erro sintatico); aqui o que se mede e
## ESCOLHA -- e um erro de digitacao no meio disso viraria ruido no dado, nao
## informacao sobre o que o jogador entendeu.
##
## Erro nao fecha a caixa: mostra o porque e deixa tentar de novo, custando
## pontos. Fechar e reabrir a cada erro so acrescentaria caminhada, nao licao
## (secao 7 do CLAUDE.md: o erro e custo pedagogico, nao punicao).

signal respondido(correto: bool, opcao: String, tempo_resposta_ms: int)
## Fechar sem responder. O pacote continua onde estava: sair da caixa e uma
## saida legitima ("nao sei ainda, volto depois"), nao uma forma de burlar o
## desafio -- sem o pacote a porta continua trancada.
signal cancelada()

@onready var _enunciado: Label = $Raiz/Painel/Coluna/Enunciado
## Coluna, e nao linha: as perguntas de conceito tem opcoes que sao frases, e
## tres frases lado a lado nao cabem em 300 px.
@onready var _opcoes: VBoxContainer = $Raiz/Painel/Coluna/Opcoes
@onready var _retorno: Label = $Raiz/Painel/Coluna/Retorno

var _configuracao: PacoteConfig = null
var _marca_de_abertura: int = 0


func _ready() -> void:
	visible = false


## A arvore fica pausada enquanto a caixa esta aberta, e no pausada nao recebe
## entrada -- por isso a tecla de sair e tratada AQUI (a caixa tem process_mode
## ALWAYS) e nao em fase_base.gd, que ficaria surdo.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("pausar"):
		get_viewport().set_input_as_handled()
		cancelada.emit()


func abrir(config: PacoteConfig) -> void:
	_configuracao = config
	_enunciado.text = config.enunciado
	_retorno.text = "escolha uma resposta:"
	_retorno.modulate = Color.WHITE

	for antigo: Node in _opcoes.get_children():
		_opcoes.remove_child(antigo)
		antigo.queue_free()

	# Ordem sorteada a cada abertura. Sem isso, a resposta certa fica sempre na
	# mesma posicao da lista e o jogador aprende a posicao em vez do conteudo --
	# o que arruinaria justamente a medida que o puzzle existe para produzir.
	var ordem := PackedStringArray(config.opcoes)
	_embaralhar(ordem)

	for opcao: String in ordem:
		var botao := Button.new()
		botao.add_theme_font_size_override("font_size", 10)
		# NENHUMA opcao e colorida, nem quando e o nome de um algoritmo.
		#
		# A cor e a pista do LABIRINTO -- serve para reconhecer a ameaca que
		# esta vindo. Dentro da caixa ela viraria muleta: o jogador pareia a cor
		# do botao com a do cachorro que acabou de ver e acerta sem entender o
		# conceito, que e exatamente o que a pergunta quer medir. Botao neutro
		# obriga a ler o enunciado.
		if config.opcoes_de_algoritmo():
			botao.text = LegendaCores.nome(opcao)
		else:
			botao.text = opcao
			botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			botao.custom_minimum_size = Vector2(0, 20)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# O valor da opcao viaja no metadado, e nao no texto do botao: em
		# APLICACAO o texto e o nome bonito ("SHA-256") e o valor e o codigo
		# ("SHA256"), entao ler o rotulo de volta daria o dado errado.
		botao.set_meta("opcao", opcao)
		botao.pressed.connect(_ao_escolher.bind(opcao))
		_opcoes.add_child(botao)

	visible = true
	_marca_de_abertura = Relogio.marca_ms()
	if _opcoes.get_child_count() > 0:
		(_opcoes.get_child(0) as Button).grab_focus()


func fechar() -> void:
	visible = false
	_configuracao = null


func esta_aberta() -> bool:
	return visible


## Usada pelos testes e pelo teclado: responde como se o botao tivesse sido
## clicado, sem depender de simular evento de mouse.
func escolher(opcao: String) -> void:
	_ao_escolher(opcao)


## Ordem em que as opcoes estao na tela agora -- existe para o teste conferir
## que o embaralhamento nao perde nem inventa opcao.
func ordem_das_opcoes() -> PackedStringArray:
	var ordem := PackedStringArray()
	for filho: Node in _opcoes.get_children():
		var botao := filho as Button
		if botao != null:
			ordem.append(String(botao.get_meta("opcao", "")))
	return ordem


## Fisher-Yates com o RNG global (ja semeado por Godot a cada execucao): nao ha
## nada aqui que precise ser reproduzivel entre partidas -- qual pergunta o
## jogador respondeu vai para a telemetria pelo identificador do pacote, nao
## pela posicao do botao.
func _embaralhar(itens: PackedStringArray) -> void:
	for i: int in range(itens.size() - 1, 0, -1):
		var j: int = randi_range(0, i)
		var troca: String = itens[i]
		itens[i] = itens[j]
		itens[j] = troca


func _ao_escolher(opcao: String) -> void:
	if _configuracao == null:
		return

	var correto: bool = opcao == _configuracao.resposta_correta
	var decorrido: int = Relogio.decorrido_ms(_marca_de_abertura)

	if correto:
		_retorno.text = _configuracao.explicacao_correta
		# Verde de "acertou", nao a cor do algoritmo: dentro da caixa nenhuma
		# cor deve ser lida como pista sobre a resposta.
		_retorno.modulate = Color(0.45, 0.88, 0.55)
	else:
		# Numa pergunta de conceito a opcao e uma frase inteira: repeti-la aqui
		# encheria o painel. O retorno diz so que errou e devolve para o
		# enunciado, que continua na tela.
		if _configuracao.opcoes_de_algoritmo():
			_retorno.text = "%s nao resolve este caso. leia de novo e tente outra." \
				% LegendaCores.nome(opcao)
		else:
			_retorno.text = "nao e essa. leia o enunciado de novo e tente outra."
		_retorno.modulate = Color(1.0, 0.55, 0.5)
		# O cronometro reinicia a cada tentativa, como no terminal: cada
		# tentativa_comando mede o tempo DAQUELA decisao, nao o acumulado.
		_marca_de_abertura = Relogio.marca_ms()

	respondido.emit(correto, opcao, decorrido)
