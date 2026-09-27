extends CasoDeTeste

## Nenhum PAINEL de conteudo pode ser transparente -- foi um bug historico
## deste projeto (ver docs/conformidade-monografia.md) e o jeito de garantir
## que ele nao volta e testar, nao so olhar a cena no editor.
##
## Varre cada cena instanciada por inteiro (e nao caminhos fixos de no): assim
## o teste continua valendo mesmo que a arvore interna de uma tela mude, o que
## e exatamente o que acabou de acontecer no editor com as abas.

## Telas de pagina inteira: o ColorRect de fundo E a tela, tem que ser opaco.
const TELAS_DE_PAGINA: PackedStringArray = [
	"res://cenas/ui/menu_principal.tscn",
	"res://cenas/ui/selecao_de_fases.tscn",
	"res://cenas/ui/editor_de_fase.tscn",
	"res://cenas/ui/dashboard_telemetria.tscn",
]

## Overlays de jogo: aparecem por cima do labirinto ainda rodando. O ColorRect
## de fundo E UM VEU translucido de proposito (o jogador continua vendo o
## labirinto atras, so mais escuro) -- so o painel de conteudo, esse sim, tem
## que ser opaco para o texto ficar legivel.
const OVERLAYS_DE_JOGO: PackedStringArray = [
	"res://cenas/ui/tela_captura.tscn",
	"res://cenas/base/caixa_puzzle.tscn",
	"res://cenas/base/painel_cifra.tscn",
	"res://cenas/base/terminal.tscn",
]


func teste_paineis_de_pagina_inteira_sao_opacos() -> void:
	await _conferir_paineis(TELAS_DE_PAGINA, true)


func teste_paineis_de_overlay_sao_opacos_com_veu_translucido() -> void:
	await _conferir_paineis(OVERLAYS_DE_JOGO, false)


func _conferir_paineis(cenas: PackedStringArray, exigir_fundo_opaco: bool) -> void:
	for caminho: String in cenas:
		var raiz: Node = load(caminho).instantiate()
		add_child(raiz)
		await get_tree().process_frame

		for no: Node in _descendentes(raiz):
			if no is ColorRect and exigir_fundo_opaco:
				afirmar_igual((no as ColorRect).color.a, 1.0,
					"%s: ColorRect '%s' opaco" % [caminho, no.name])
			elif no is PanelContainer:
				var estilo: StyleBox = (no as PanelContainer).get_theme_stylebox("panel")
				if estilo is StyleBoxFlat:
					afirmar_igual((estilo as StyleBoxFlat).bg_color.a, 1.0,
						"%s: painel '%s' opaco" % [caminho, no.name])

		raiz.queue_free()
		await get_tree().process_frame


func _descendentes(no: Node) -> Array[Node]:
	var lista: Array[Node] = []
	for filho: Node in no.get_children():
		lista.append(filho)
		lista.append_array(_descendentes(filho))
	return lista
