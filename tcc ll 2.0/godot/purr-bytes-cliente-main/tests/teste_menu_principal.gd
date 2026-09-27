extends CasoDeTeste

## Regressao do mesmo tipo de bug que motivou este arquivo originalmente: um
## botao do menu preso num placeholder que nunca troca de cena de verdade.
##
## O jogo nao tem fase propria embutida (ADR 0012: virou ferramenta de
## autoria) -- "escolher fase" e o unico caminho para jogar, entao e ele que
## este teste cobre agora, no lugar do antigo botao "jogar" (que abria
## fase_01.tscn direto e foi removido).
##
## Este arquivo instancia cenas/ui/menu_principal.tscn de verdade, aciona o
## MESMO caminho que um clique no botao aciona (a funcao conectada ao sinal
## `pressed`), e confere que a cena ativa da SceneTree realmente muda -- nao
## só que uma função interna "não lançou erro".


func depois() -> void:
	if Sessao.ativa:
		Sessao.encerrar()


func teste_botao_escolher_fase_troca_para_a_tela_de_selecao() -> void:
	var cena: PackedScene = load("res://cenas/ui/menu_principal.tscn") as PackedScene
	var menu: Control = cena.instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame

	menu._ao_escolher_fase()
	# change_scene_to_file() e adiado para o proximo idle frame.
	await get_tree().process_frame
	await get_tree().process_frame

	var cena_atual: Node = get_tree().current_scene
	afirmar_nao_nulo(cena_atual, "current_scene passou a existir depois de 'escolher fase'")
	afirmar_verdadeiro(cena_atual.get_script() != null
			and cena_atual.get_script().resource_path.ends_with("selecao_de_fases.gd"),
		"a cena carregada e a tela de selecao, nao o menu preso")

	# change_scene_to_file() nao gerencia `menu` (adicionada por fora, via
	# root.add_child) -- sem liberar os dois, `menu` fica orfa sob root,
	# processando para sempre.
	if is_instance_valid(menu) and menu != cena_atual:
		menu.queue_free()
	if is_instance_valid(cena_atual):
		cena_atual.queue_free()
	await get_tree().process_frame
