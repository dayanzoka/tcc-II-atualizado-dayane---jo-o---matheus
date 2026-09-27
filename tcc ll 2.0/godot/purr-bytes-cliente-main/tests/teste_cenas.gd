extends CasoDeTeste

## Cena quebrada nao aparece em teste de logica: ela aparece na hora da
## apresentacao. Aqui cada cena e carregada, instanciada e tem seus caminhos de
## no conferidos -- que sao os mesmos que os scripts usam em @onready.
##
## Tambem cobre o criterio de aceite do Marco 0: fase_base.tscn nao pode ser
## jogada direto e tem que falhar com mensagem clara sem FaseConfig.

const CENAS: PackedStringArray = [
	"res://cenas/base/fase_base.tscn",
	"res://cenas/base/jogador.tscn",
	"res://cenas/base/cachorro.tscn",
	"res://cenas/base/terminal.tscn",
	"res://cenas/ui/hud.tscn",
	"res://cenas/ui/tela_captura.tscn",
	"res://cenas/ui/menu_principal.tscn",
	"res://cenas/base/painel_cifra.tscn",
	"res://cenas/base/painel_pause.tscn",
]

var _nivel_original: String


func antes() -> void:
	_nivel_original = Registro.nome_do_nivel()
	# fase_base sem configuracao grita por push_error de proposito.
	Registro.definir_nivel_por_nome("SILENCIO")


func depois() -> void:
	Registro.definir_nivel_por_nome(_nivel_original)


func teste_todas_as_cenas_carregam() -> void:
	for caminho: String in CENAS:
		var cena: PackedScene = load(caminho) as PackedScene
		if not afirmar_nao_nulo(cena, "cena carrega: %s" % caminho):
			continue
		var raiz: Node = cena.instantiate()
		afirmar_nao_nulo(raiz, "cena instancia: %s" % caminho)
		raiz.free()


func teste_arvore_da_cena_pai() -> void:
	var fase: Node = load("res://cenas/base/fase_base.tscn").instantiate()
	# Os mesmos caminhos que fase_base.gd usa em @onready.
	for caminho: String in [
		"Labirinto", "Marcadores", "Marcadores/PontoDeEntrada", "Marcadores/PontoDeSaida",
		"Marcadores/Regioes", "Jogador", "Cachorro", "CameraJogador", "Hud", "Terminal",
		"PainelCifra", "TelaCaptura", "PainelDePause", "AvisoDeConfiguracao",
		"AvisoDeConfiguracao/Fundo/Texto",
	]:
		afirmar_nao_nulo(fase.get_node_or_null(caminho), "fase_base tem o no %s" % caminho)

	afirmar_verdadeiro(fase.get_node("Labirinto") is TileMapLayer,
		"o labirinto e um TileMapLayer (nao o TileMap depreciado)")
	afirmar_verdadeiro(fase.get_node("Jogador") is Jogador, "Jogador tem o script certo")
	afirmar_verdadeiro(fase.get_node("Cachorro") is Cachorro, "Cachorro tem o script certo")
	afirmar_verdadeiro(fase.get_node("Terminal") is Terminal, "Terminal tem o script certo")
	fase.free()


func teste_cena_pai_recusa_rodar_sem_configuracao() -> void:
	var fase: FaseBase = load("res://cenas/base/fase_base.tscn").instantiate() as FaseBase
	afirmar_nulo(fase.configuracao, "fase_base nasce sem FaseConfig")

	add_child(fase)
	await get_tree().process_frame

	afirmar_verdadeiro(fase.aviso.visible,
		"o aviso de configuracao aparece na tela, e nao so no log")
	afirmar_contem(fase.get_node("AvisoDeConfiguracao/Fundo/Texto").text,
		"cena pai", "a mensagem explica que esta e a cena pai")
	afirmar_falso(fase.is_physics_processing(),
		"a fase nao roda: sem regra nenhuma, andar pelo labirinto seria pior que travar")

	fase.queue_free()
	await get_tree().process_frame


func teste_tileset_tem_a_camada_solido() -> void:
	var conjunto: TileSet = load("res://recursos/tilesets/labirinto.tres") as TileSet
	if not afirmar_nao_nulo(conjunto, "TileSet do labirinto carrega"):
		return

	afirmar_igual(conjunto.get_custom_data_layers_count(), 1, "uma camada de dados customizados")
	afirmar_igual(conjunto.get_custom_data_layer_name(0), "solido",
		"a camada se chama 'solido' -- e dela que o A* e a colisao leem")
	afirmar_igual(conjunto.get_custom_data_layer_type(0), TYPE_BOOL, "a camada e booleana")
	afirmar_igual(conjunto.tile_size, Vector2i(16, 16), "tile de 16x16")


func teste_tiles_de_piso_e_parede() -> void:
	var conjunto: TileSet = load("res://recursos/tilesets/labirinto.tres") as TileSet
	var fonte: TileSetAtlasSource = conjunto.get_source(0) as TileSetAtlasSource
	if not afirmar_nao_nulo(fonte, "fonte de atlas presente"):
		return

	var piso: TileData = fonte.get_tile_data(Vector2i(0, 0), 0)
	var parede: TileData = fonte.get_tile_data(Vector2i(1, 0), 0)
	afirmar_nao_nulo(piso, "tile de piso existe no atlas")
	afirmar_nao_nulo(parede, "tile de parede existe no atlas")

	afirmar_falso(bool(piso.get_custom_data("solido")), "piso nao e solido")
	afirmar_verdadeiro(bool(parede.get_custom_data("solido")), "parede e solida")
	afirmar_igual(parede.get_collision_polygons_count(0), 1,
		"a parede tem poligono de colisao: mapa e colisao sao o mesmo dado")
	afirmar_igual(piso.get_collision_polygons_count(0), 0, "o piso nao colide")


func teste_cena_principal_do_projeto_existe() -> void:
	var principal: String = String(ProjectSettings.get_setting("application/run/main_scene", ""))
	afirmar_igual(principal, "res://cenas/ui/menu_principal.tscn", "cena principal configurada")
	afirmar_verdadeiro(ResourceLoader.exists(principal), "a cena principal existe no disco")
