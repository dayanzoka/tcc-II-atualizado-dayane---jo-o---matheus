class_name PainelCifra
extends CanvasLayer

## Painel de demonstração comparativa (Eixo 2, Marco 2): texto claro, chave
## alinhada letra a letra e texto cifrado, lado a lado. O alinhamento em si é
## calculado por `scripts/cripto/demonstracao_cifra.gd` (puro, testável); este
## arquivo só desenha o que aquele cálculo devolve.
##
## Cada letra vira uma coluna (VBoxContainer com 3 Labels) dentro de um
## HBoxContainer -- alinhamento por layout, não por contagem de caracteres, o
## que continua correto mesmo quando um símbolo de chave tem mais de um
## dígito (Cesar com chave >= 10).

signal aberto()
signal fechado()

const _TAMANHO_FONTE: int = 8
const _COR_CHAVE: Color = Color(1.0, 0.85, 0.3)
const _COR_DIVERGENTE: Color = Color(1.0, 0.4, 0.4)

@onready var _raiz: Control = $Raiz
@onready var _titulo: Label = $Raiz/Painel/Margem/Coluna/Titulo
@onready var _colunas: HBoxContainer = $Raiz/Painel/Margem/Coluna/Colunas


func _ready() -> void:
	visible = false


func abrir(titulo: String, texto_claro: String, chave: String, cifra: Cifra) -> void:
	_titulo.text = titulo
	_montar_colunas(texto_claro, chave, cifra)
	visible = true
	aberto.emit()


## Painel de efeito avalanche (Marco 3, SHA-256): dois digests lado a lado,
## dígito a dígito, com o que diverge destacado -- "alterar um caractere muda
## o digest inteiro" (seção 8 do CLAUDE.md).
func abrir_avalanche(titulo: String, texto_a: String, texto_b: String) -> void:
	_titulo.text = titulo
	_montar_colunas_avalanche(texto_a, texto_b)
	visible = true
	aberto.emit()


func fechar() -> void:
	visible = false
	fechado.emit()


func esta_aberto() -> bool:
	return visible


func _montar_colunas(texto_claro: String, chave: String, cifra: Cifra) -> void:
	for filho: Node in _colunas.get_children():
		filho.queue_free()

	var linhas: Array[DemonstracaoCifra.Linha] = DemonstracaoCifra.montar(texto_claro, chave, cifra)
	for linha: DemonstracaoCifra.Linha in linhas:
		_colunas.add_child(_criar_coluna(linha))


func _criar_coluna(linha: DemonstracaoCifra.Linha) -> VBoxContainer:
	var coluna := VBoxContainer.new()

	var rotulo_claro := Label.new()
	rotulo_claro.text = linha.claro
	rotulo_claro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_claro.add_theme_font_size_override("font_size", _TAMANHO_FONTE)
	coluna.add_child(rotulo_claro)

	var rotulo_chave := Label.new()
	rotulo_chave.text = linha.chave if linha.chave != "" else "·"
	rotulo_chave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_chave.add_theme_font_size_override("font_size", _TAMANHO_FONTE)
	rotulo_chave.add_theme_color_override("font_color", _COR_CHAVE)
	coluna.add_child(rotulo_chave)

	var rotulo_cifrado := Label.new()
	rotulo_cifrado.text = linha.cifrado
	rotulo_cifrado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_cifrado.add_theme_font_size_override("font_size", _TAMANHO_FONTE)
	coluna.add_child(rotulo_cifrado)

	return coluna


func _montar_colunas_avalanche(texto_a: String, texto_b: String) -> void:
	for filho: Node in _colunas.get_children():
		filho.queue_free()

	var colunas: Array[DemonstracaoAvalanche.Coluna] = DemonstracaoAvalanche.montar(texto_a, texto_b)
	for coluna: DemonstracaoAvalanche.Coluna in colunas:
		_colunas.add_child(_criar_coluna_avalanche(coluna))


func _criar_coluna_avalanche(coluna: DemonstracaoAvalanche.Coluna) -> VBoxContainer:
	var caixa := VBoxContainer.new()
	var cor: Color = _COR_DIVERGENTE if coluna.diferente else Color.WHITE

	var rotulo_a := Label.new()
	rotulo_a.text = coluna.digito_a
	rotulo_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_a.add_theme_font_size_override("font_size", _TAMANHO_FONTE)
	rotulo_a.add_theme_color_override("font_color", cor)
	caixa.add_child(rotulo_a)

	var rotulo_b := Label.new()
	rotulo_b.text = coluna.digito_b
	rotulo_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_b.add_theme_font_size_override("font_size", _TAMANHO_FONTE)
	rotulo_b.add_theme_color_override("font_color", cor)
	caixa.add_child(rotulo_b)

	return caixa
