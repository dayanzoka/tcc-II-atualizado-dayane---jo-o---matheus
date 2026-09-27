extends CasoDeTeste

## Arte dos personagens: folhas PNG -> SpriteFrames -> AnimatedSprite2D.
##
## O que protege: (a) as 5 animacoes com 4 quadros existirem nos dois .tres
## (um quadro faltando so apareceria jogando), (b) a regra de direcao do
## AnimadorDirecional e (c) as cenas base usarem a arte nova sem perder o
## tingimento por cor do cachorro, que e mecanica e nao enfeite.

const QUADROS: Dictionary = {
	"gato": "res://recursos/arte/gato_frames.tres",
	"cachorro": "res://recursos/arte/cachorro_frames.tres",
}
const ANIMACOES: Array[StringName] = [
	AnimadorDirecional.ANDAR_BAIXO, AnimadorDirecional.ANDAR_DIREITA,
	AnimadorDirecional.ANDAR_CIMA, AnimadorDirecional.ANDAR_ESQUERDA,
	AnimadorDirecional.PARADO,
]


func teste_sprite_frames_tem_as_cinco_animacoes_completas() -> void:
	for nome: String in QUADROS:
		var quadros: SpriteFrames = load(QUADROS[nome]) as SpriteFrames
		if not afirmar_nao_nulo(quadros, "%s: SpriteFrames carrega" % nome):
			continue
		for animacao: StringName in ANIMACOES:
			if not afirmar_verdadeiro(quadros.has_animation(animacao),
					"%s tem a animacao %s" % [nome, animacao]):
				continue
			afirmar_igual(quadros.get_frame_count(animacao), 4,
				"%s/%s tem 4 quadros" % [nome, animacao])
			afirmar_verdadeiro(quadros.get_animation_loop(animacao),
				"%s/%s repete em ciclo" % [nome, animacao])
			var primeiro: Texture2D = quadros.get_frame_texture(animacao, 0)
			afirmar_igual(primeiro.get_size(), Vector2(24, 24),
				"%s/%s: quadro de 24x24" % [nome, animacao])


func teste_quadros_nao_sao_transparentes() -> void:
	# Quadro todo transparente = recorte fora da folha (grade errada no gerador).
	for nome: String in QUADROS:
		var quadros: SpriteFrames = load(QUADROS[nome]) as SpriteFrames
		for animacao: StringName in ANIMACOES:
			for i: int in quadros.get_frame_count(animacao):
				var imagem: Image = quadros.get_frame_texture(animacao, i).get_image()
				afirmar_verdadeiro(not imagem.is_invisible(),
					"%s/%s quadro %d tem desenho" % [nome, animacao, i])


func teste_direcao_escolhe_a_animacao_pelo_eixo_dominante() -> void:
	var animador := AnimadorDirecional.new()
	animador.velocidade_minima = 6.0
	afirmar_igual(animador.animacao_para(Vector2.ZERO), AnimadorDirecional.PARADO, "parado")
	afirmar_igual(animador.animacao_para(Vector2(3, 3)), AnimadorDirecional.PARADO,
		"abaixo do limiar conta como parado (lerp soltando a tecla)")
	afirmar_igual(animador.animacao_para(Vector2(70, 0)), AnimadorDirecional.ANDAR_DIREITA, "direita")
	afirmar_igual(animador.animacao_para(Vector2(-70, 0)), AnimadorDirecional.ANDAR_ESQUERDA, "esquerda")
	afirmar_igual(animador.animacao_para(Vector2(0, 70)), AnimadorDirecional.ANDAR_BAIXO,
		"y cresce para baixo no Godot")
	afirmar_igual(animador.animacao_para(Vector2(0, -70)), AnimadorDirecional.ANDAR_CIMA, "cima")
	afirmar_igual(animador.animacao_para(Vector2(50, -40)), AnimadorDirecional.ANDAR_DIREITA,
		"diagonal: eixo dominante decide")
	afirmar_igual(animador.animacao_para(Vector2(-30, 40)), AnimadorDirecional.ANDAR_BAIXO,
		"diagonal: eixo dominante decide (vertical)")
	animador.free()


func teste_cenas_base_usam_a_arte_animada() -> void:
	for caminho: String in ["res://cenas/base/jogador.tscn", "res://cenas/base/cachorro.tscn"]:
		var no: Node = (load(caminho) as PackedScene).instantiate()
		var sprite: Node = no.get_node_or_null("Sprite")
		afirmar_verdadeiro(sprite is AnimadorDirecional, "%s: Sprite e AnimadorDirecional" % caminho)
		if sprite is AnimatedSprite2D:
			afirmar_nao_nulo((sprite as AnimatedSprite2D).sprite_frames, "%s tem SpriteFrames" % caminho)
		no.free()


func teste_jogador_anima_ao_andar_e_senta_ao_parar() -> void:
	var jogador: Jogador = (load("res://cenas/base/jogador.tscn") as PackedScene).instantiate() as Jogador
	get_tree().root.add_child(jogador)
	var sprite: AnimadorDirecional = jogador.get_node("Sprite") as AnimadorDirecional
	afirmar_igual(sprite.animation, AnimadorDirecional.PARADO, "nasce parado")

	sprite.atualizar(Vector2(0, -jogador.velocidade))
	afirmar_igual(sprite.animation, AnimadorDirecional.ANDAR_CIMA, "andando para cima")
	afirmar_verdadeiro(sprite.is_playing(), "a animacao roda")
	sprite.atualizar(Vector2.ZERO)
	afirmar_igual(sprite.animation, AnimadorDirecional.PARADO, "soltou a tecla: senta")
	jogador.free()


func teste_cor_do_cachorro_vai_para_o_anel_e_nao_tinge_a_arte() -> void:
	var cachorro: Cachorro = (load("res://cenas/base/cachorro.tscn") as PackedScene).instantiate() as Cachorro
	get_tree().root.add_child(cachorro)
	var cor := Color(0.3, 0.6, 1.0)
	cachorro.definir_cor(cor)
	afirmar_igual((cachorro.get_node("Marcador") as MarcadorDeCor).cor, cor,
		"a cor do vigia aparece no anel do chao")
	afirmar_igual((cachorro.get_node("Sprite") as CanvasItem).modulate, Color.WHITE,
		"a arte colorida do cachorro nao e tingida")
	cachorro.free()


func teste_cachorro_anda_nas_quatro_direcoes() -> void:
	# A folha atual do cachorro tem costas e frente: subindo ele mostra as
	# costas, em vez de andar de lado como a folha anterior obrigava.
	var cachorro: Cachorro = (load("res://cenas/base/cachorro.tscn") as PackedScene).instantiate() as Cachorro
	get_tree().root.add_child(cachorro)
	var sprite: AnimadorDirecional = cachorro.get_node("Sprite") as AnimadorDirecional
	afirmar_falso(sprite.lateral_no_eixo_vertical, "folha com costas: nada de lateral na vertical")
	sprite.atualizar(Vector2(0, -60))
	afirmar_igual(sprite.animation, AnimadorDirecional.ANDAR_CIMA, "subindo: costas")
	sprite.atualizar(Vector2(0, 60))
	afirmar_igual(sprite.animation, AnimadorDirecional.ANDAR_BAIXO, "descendo: frente")
	cachorro.free()


func teste_folha_sem_costas_pode_ficar_na_lateral() -> void:
	# Recurso do AnimadorDirecional para folhas sem vista de costas.
	var animador := AnimadorDirecional.new()
	animador.lateral_no_eixo_vertical = true
	animador.sprite_frames = load("res://recursos/arte/cachorro_frames.tres") as SpriteFrames
	animador.atualizar(Vector2(-60, 0))
	animador.atualizar(Vector2(0, -60))
	afirmar_igual(animador.animation, AnimadorDirecional.ANDAR_ESQUERDA,
		"subindo depois de ir para a esquerda: continua de lado")
	animador.free()

func teste_fase_ordena_personagens_por_altura() -> void:
	# Sprite de 24px sobre tile de 16 invade a celula de cima: sem y-sort, um
	# cachorro abaixo do gato apareceria atras dele. O labirinto fica na origem
	# (y = 0), entao continua sendo desenhado antes de todos.
	var fase: Node2D = (load("res://cenas/base/fase_base.tscn") as PackedScene).instantiate() as Node2D
	afirmar_verdadeiro(fase.y_sort_enabled, "FaseBase ordena os filhos por y")
	afirmar_igual((fase.get_node("Labirinto") as Node2D).position, Vector2.ZERO,
		"labirinto na origem, atras dos personagens")
	fase.free()
