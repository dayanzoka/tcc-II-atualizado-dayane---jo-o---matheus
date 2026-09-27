class_name Hud
extends CanvasLayer

## Placar de vidas, pontuacao e fase.
##
## Escuta os sinais do autoload Sessao em vez de ser atualizado pela fase. Assim
## a fase nao precisa saber que a HUD existe, e uma segunda tela que mostre o
## mesmo estado (a tela de captura, por exemplo) escuta os mesmos sinais sem
## nenhum acoplamento novo.

@onready var _vidas: Label = $Raiz/Linha/Vidas
@onready var _pontuacao: Label = $Raiz/Linha/Pontuacao
@onready var _pacotes: Label = $Raiz/Linha/Pacotes
@onready var _titulo: Label = $Raiz/Linha/Titulo
@onready var _protecao: Label = $Raiz/Linha/Protecao
@onready var _painel_comandos: PanelContainer = $Raiz/Comandos
@onready var _lista_comandos: HBoxContainer = $Raiz/Comandos/Margem/Lista

## Tamanho do quadrado de cor na legenda de comandos.
@export var tamanho_da_amostra_de_cor: Vector2 = Vector2(7, 7)


func _ready() -> void:
	Sessao.vidas_alteradas.connect(_ao_mudar_vidas)
	Sessao.pontuacao_alterada.connect(_ao_mudar_pontuacao)
	_ao_mudar_vidas(Sessao.vidas)
	_ao_mudar_pontuacao(Sessao.pontuacao)
	mostrar_protecao(false, 0.0, "")
	mostrar_pacotes(0, 0)
	mostrar_comandos([])


func definir_titulo(texto: String) -> void:
	_titulo.text = texto


## Progresso da coleta. Fica em verde quando completa porque e o momento em que
## a porta destranca -- o jogador precisa perceber isso sem reler o terminal.
func mostrar_pacotes(coletados: int, total: int) -> void:
	_pacotes.visible = total > 0
	_pacotes.text = "pacotes %d/%d" % [coletados, total]
	_pacotes.modulate = Color(0.40, 0.88, 0.52) if coletados >= total and total > 0 else Color.WHITE


## Mostra QUAL cifra esta ativa e por quanto tempo -- "cifra ativa" sozinho nao
## diria ao jogador se ele esta protegido do interceptador que esta vindo.
##
## Em cor neutra, de proposito: a cor e identidade visual do cachorro, nao um
## codigo que diga qual cifra usar. Pintar o aviso com a cor de um algoritmo
## sugeriria uma associacao que o jogo nao promete.
func mostrar_protecao(ativa: bool, restante_s: float, algoritmo: String = "") -> void:
	_protecao.modulate = Color.WHITE
	if ativa and algoritmo.is_empty():
		# Protecao por comando livre (fases de autoria): nao ha cifra a nomear.
		_protecao.text = "comando ativo %0.1fs" % restante_s
	elif ativa:
		_protecao.text = "%s ativa %0.1fs" % [LegendaCores.nome(algoritmo), restante_s]
	else:
		_protecao.text = "texto claro"


func _ao_mudar_vidas(vidas: int) -> void:
	_vidas.text = "vidas %d" % vidas


func _ao_mudar_pontuacao(pontuacao: int) -> void:
	_pontuacao.text = "pontos %d" % pontuacao


## Legenda fixa "cor do vigia -> comando", no rodape. Cada item e
## {"cor": Color, "texto": String}; lista vazia esconde a legenda.
##
## Aqui a cor E informacao (ao contrario do aviso de protecao acima): o jogador
## liga o anel no chao do vigia ao comando que o para.
func mostrar_comandos(itens: Array[Dictionary]) -> void:
	for filho: Node in _lista_comandos.get_children():
		_lista_comandos.remove_child(filho)
		filho.queue_free()

	_painel_comandos.visible = not itens.is_empty()
	if itens.is_empty():
		return

	var rotulo := Label.new()
	rotulo.text = "comandos:"
	rotulo.add_theme_font_size_override("font_size", 8)
	_lista_comandos.add_child(rotulo)

	for item: Dictionary in itens:
		var amostra := ColorRect.new()
		amostra.color = item.get("cor", Color.WHITE) as Color
		amostra.custom_minimum_size = tamanho_da_amostra_de_cor
		amostra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_lista_comandos.add_child(amostra)

		var texto := Label.new()
		texto.text = String(item.get("texto", ""))
		texto.add_theme_font_size_override("font_size", 8)
		_lista_comandos.add_child(texto)


func comandos_visiveis() -> PackedStringArray:
	var textos := PackedStringArray()
	if not _painel_comandos.visible:
		return textos
	for filho: Node in _lista_comandos.get_children():
		if filho is Label and (filho as Label).text != "comandos:":
			textos.append((filho as Label).text)
	return textos
