extends SceneTree

## Gera os SpriteFrames (.tres) dos personagens a partir das folhas PNG.
##
##   godot --headless --path . --script res://tools/gerar_sprite_frames.gd
##
## Por que um script e nao o painel SpriteFrames do editor: as duas folhas
## seguem a mesma grade (5 linhas x 4 quadros de 24x24), e montar 40 quadros a
## mao e onde nasce o erro de quadro trocado. O resultado e um .tres comum --
## depois de gerado, da para abrir e ajustar no editor normalmente.
##
## Grade da folha (linha -> animacao), a mesma da arte original do gato:
##   0 andar_baixo | 1 andar_direita | 2 andar_cima | 3 andar_esquerda | 4 parado

const TAMANHO_QUADRO: Vector2i = Vector2i(24, 24)
const QUADROS_POR_LINHA: int = 4
const ANIMACOES: Array[StringName] = [
	&"andar_baixo", &"andar_direita", &"andar_cima", &"andar_esquerda", &"parado",
]
## Ritmo de passo lido na arte: 4 quadros por ciclo a 8 qps da ~2 passos/s,
## o que casa com a velocidade de 70 px/s do jogador em tile de 16.
const QPS_ANDAR: float = 8.0
## Parado e "respirar", nao andar: bem mais lento.
const QPS_PARADO: float = 3.0

const FOLHAS: Dictionary = {
	"res://recursos/arte/gato.png": "res://recursos/arte/gato_frames.tres",
	"res://recursos/arte/cachorro.png": "res://recursos/arte/cachorro_frames.tres",
}


func _initialize() -> void:
	var codigo: int = 0
	for origem: String in FOLHAS:
		if not _gerar(origem, FOLHAS[origem]):
			codigo = 1
	quit(codigo)


func _gerar(caminho_folha: String, destino: String) -> bool:
	var folha: Texture2D = load(caminho_folha) as Texture2D
	if folha == null:
		push_error("folha nao encontrada: %s (rode --import antes)" % caminho_folha)
		return false

	var quadros := SpriteFrames.new()
	quadros.remove_animation(&"default")
	for linha: int in ANIMACOES.size():
		var nome: StringName = ANIMACOES[linha]
		quadros.add_animation(nome)
		quadros.set_animation_loop(nome, true)
		quadros.set_animation_speed(nome, QPS_PARADO if nome == &"parado" else QPS_ANDAR)
		for coluna: int in QUADROS_POR_LINHA:
			# AtlasTexture recorta a folha sem duplicar pixels: um PNG so no
			# disco, 20 regioes dentro do .tres.
			var recorte := AtlasTexture.new()
			recorte.atlas = folha
			recorte.region = Rect2(Vector2(coluna * TAMANHO_QUADRO.x, linha * TAMANHO_QUADRO.y),
				Vector2(TAMANHO_QUADRO))
			quadros.add_frame(nome, recorte)

	var erro: Error = ResourceSaver.save(quadros, destino)
	if erro != OK:
		push_error("falha ao salvar %s (erro %d)" % [destino, erro])
		return false
	print("gerado: %s" % destino)
	return true
