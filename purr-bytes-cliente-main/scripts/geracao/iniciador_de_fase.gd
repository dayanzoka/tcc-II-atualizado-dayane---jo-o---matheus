class_name IniciadorDeFase
extends RefCounted

## Poe em jogo uma FaseConfig que NAO tem cena propria.
##
## As fases 1 a 3 sao cenas herdadas de fase_base.tscn, cada uma com o seu
## FaseConfig atribuido no editor -- e por isso o menu as abre com
## change_scene_to_file(). Uma fase criada pelo professor nao tem .tscn nenhum:
## ela existe so como .json, e o FaseConfig nasce em memoria.
##
## change_scene_to_file() nao aceita parametro, entao a troca e feita a mao:
## instanciar fase_base.tscn, ATRIBUIR a configuracao, e so entao adicionar a
## arvore. A ordem importa -- FaseBase._ready() le `configuracao` e recusa a
## fase se ela estiver nula, entao atribuir depois do add_child mostraria a tela
## de erro por um quadro antes de funcionar.
##
## Isso evita um autoload novo so para carregar um ponteiro entre telas.

const CENA_BASE: String = "res://cenas/base/fase_base.tscn"


static func jogar(arvore: SceneTree, config: FaseConfig) -> FaseBase:
	if config == null:
		Registro.erro("IniciadorDeFase", "tentativa de jogar uma fase nula")
		return null

	var cena: PackedScene = load(CENA_BASE) as PackedScene
	if cena == null:
		Registro.erro("IniciadorDeFase", "nao foi possivel carregar %s" % CENA_BASE)
		return null

	var fase: FaseBase = cena.instantiate() as FaseBase
	fase.configuracao = config

	var anterior: Node = arvore.current_scene
	arvore.root.add_child(fase)
	arvore.current_scene = fase

	# A tela anterior sai depois de a nova entrar: liberar antes deixaria a
	# arvore sem current_scene por um quadro.
	if anterior != null and is_instance_valid(anterior):
		anterior.queue_free()

	return fase


## Abre direto do arquivo, devolvendo os erros de validacao quando houver --
## quem chama decide se mostra na tela ou so registra.
static func jogar_arquivo(arvore: SceneTree, caminho: String) -> PackedStringArray:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
	if not resultado.ok():
		return resultado.erros

	jogar(arvore, resultado.config)
	return PackedStringArray()
