extends CasoDeTeste

## Duas correcoes da fase de autoria:
##
##   1. "reiniciar" no menu de pause recarregava fase_base.tscn do disco -- e a
##      fase de autoria nao tem .tscn propria, entao voltava sem FaseConfig e
##      caia na tela de "configuracao invalida".
##   2. O jogador nao via os comandos que param os vigias. Agora a fase pode
##      mostra-los (FaseConfig.mostrar_comandos), e a de exemplo mostra.

var _fase: FaseBase = null
var _mock: TransporteMock = null


func antes() -> void:
	_mock = TransporteMock.new(caminho_temporario("reiniciar_mock.jsonl"))
	Telemetria.reiniciar(_mock, caminho_temporario("reiniciar_fila.json"))
	Sessao.iniciar()


func depois() -> void:
	get_tree().paused = false
	var atual: Node = get_tree().current_scene
	if atual is FaseBase and is_instance_valid(atual):
		atual.queue_free()
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()
	await get_tree().process_frame


func _config_do_exemplo() -> FaseConfig:
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		JSON.stringify(CarregadorFaseJson._exemplo()))
	return lido.config


func _jogar(config: FaseConfig) -> FaseBase:
	_fase = IniciadorDeFase.jogar(get_tree(), config)
	await get_tree().process_frame
	return _fase


func _cachorro_com_comando(fase: FaseBase, comando: String) -> Cachorro:
	for alvo: Cachorro in fase.cachorros:
		if alvo.comando_para_bloquear == comando:
			return alvo
	return null


func _cachorro_que_so_persegue(fase: FaseBase) -> Cachorro:
	for alvo: Cachorro in fase.cachorros:
		if fase._apenas_persegue(alvo):
			return alvo
	return null


# ---------------------------------------------------------------------------
# Reiniciar
# ---------------------------------------------------------------------------

func teste_reiniciar_fase_de_autoria_volta_com_a_mesma_configuracao() -> void:
	var config: FaseConfig = _config_do_exemplo()
	var fase: FaseBase = await _jogar(config)
	if not afirmar_nao_nulo(fase, "a fase de exemplo entra em jogo"):
		return

	fase.reiniciar()
	await get_tree().process_frame
	await get_tree().process_frame

	var nova: FaseBase = get_tree().current_scene as FaseBase
	if not afirmar_nao_nulo(nova, "depois de reiniciar, a cena atual continua sendo uma fase"):
		return
	afirmar_diferente(nova, fase, "e uma partida NOVA, nao a mesma instancia")
	afirmar_falso(nova.aviso.visible,
		"e nao caiu na tela de 'configuracao invalida' (o bug do reload_current_scene)")
	afirmar_igual(nova.configuracao.id_fase, config.id_fase, "mesma fase: mesmo id_fase")
	afirmar_igual(nova.cachorros.size(), config.cachorros.size(), "com os vigias da fase")
	afirmar_igual(Sessao.id_fase, config.id_fase, "a sessao entrou de novo na fase")
	afirmar_igual(Sessao.vidas, config.vidas_iniciais, "com as vidas cheias")


# ---------------------------------------------------------------------------
# Comandos a vista
# ---------------------------------------------------------------------------

func teste_fase_de_exemplo_mostra_os_comandos_na_hud() -> void:
	var config: FaseConfig = _config_do_exemplo()
	afirmar_verdadeiro(config.mostrar_comandos, "o exemplo liga mostrar_comandos")
	afirmar_contem(config.briefing_pedagogico, "trocar senha", "o briefing diz o comando azul")
	afirmar_contem(config.briefing_pedagogico, "ativar 2fa", "e o laranja")

	var fase: FaseBase = await _jogar(config)
	afirmar_igual(fase.hud.comandos_visiveis(),
		PackedStringArray(["trocar senha", "ativar 2fa", "cifrar senha chave=3", "sem comando: fuja"]),
		"a legenda da HUD lista o comando de cada vigia, na ordem da fase")


func teste_fase_sem_mostrar_comandos_nao_entrega_a_resposta() -> void:
	var config: FaseConfig = _config_do_exemplo()
	config.mostrar_comandos = false
	var fase: FaseBase = await _jogar(config)
	afirmar_tamanho(fase.hud.comandos_visiveis(), 0, "fase de avaliacao: legenda escondida")

	var azul: Cachorro = _cachorro_com_comando(fase, "trocar senha")
	var explicacao: String = fase._explicacao_da_captura(azul)
	afirmar_falso(explicacao.contains("trocar senha"), "nem a tela de captura entrega o comando")
	afirmar_contem(explicacao, "terminal", "mas diz onde procurar")


func teste_captura_explica_o_comando_certo() -> void:
	var fase: FaseBase = await _jogar(_config_do_exemplo())
	var azul: Cachorro = _cachorro_com_comando(fase, "trocar senha")
	var explicacao: String = fase._explicacao_da_captura(azul)
	afirmar_contem(explicacao, "'trocar senha'", "a captura diz o comando daquele vigia")
	afirmar_falso(explicacao.contains("cifrar"),
		"e nao manda cifrar -- vigia de comando nao e vigia de cifra")

	var vermelho: Cachorro = _cachorro_que_so_persegue(fase)
	afirmar_contem(fase._explicacao_da_captura(vermelho), "fugir", "o que so persegue: fuja")


func teste_vigia_que_so_persegue_nao_e_parado_por_cifra() -> void:
	var fase: FaseBase = await _jogar(_config_do_exemplo())
	var vermelho: Cachorro = _cachorro_que_so_persegue(fase)
	var azul: Cachorro = _cachorro_com_comando(fase, "trocar senha")

	fase.jogador.ativar_protecao(10.0, "CESAR")
	afirmar_falso(fase._protegido_contra(vermelho),
		"cifrar nao para o vigia sem comando (antes, qualquer cifra o desligava)")

	fase.jogador.ativar_protecao(10.0, "", "trocar senha")
	afirmar_verdadeiro(fase._protegido_contra(azul), "o comando certo para o vigia azul")
	afirmar_falso(fase._protegido_contra(vermelho), "e continua sem parar o vermelho")


# ---------------------------------------------------------------------------
# JSON e migracao do exemplo ja gravado
# ---------------------------------------------------------------------------

func teste_mostrar_comandos_faz_ida_e_volta_no_json() -> void:
	var config: FaseConfig = _config_do_exemplo()
	var dados: Dictionary = CarregadorFaseJson.para_dicionario(config)
	afirmar_verdadeiro(dados.get("mostrar_comandos") == true, "grava mostrar_comandos")
	var relido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(dados))
	afirmar_verdadeiro(relido.config.mostrar_comandos, "e le de volta")

	dados.erase("mostrar_comandos")
	var antigo: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(dados))
	afirmar_falso(antigo.config.mostrar_comandos, "arquivo antigo, sem o campo: nao mostra")


func _gravar_exemplo(dados: Dictionary) -> String:
	CarregadorFaseJson.garantir_pasta()
	var caminho: String = CarregadorFaseJson.pasta_das_fases.path_join(CarregadorFaseJson.NOME_DO_EXEMPLO)
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(dados))
	arquivo.close()
	return caminho


func teste_exemplo_antigo_ganha_os_comandos_e_mantem_o_id() -> void:
	var antigo: Dictionary = CarregadorFaseJson._exemplo()
	antigo.erase("mostrar_comandos")
	antigo["briefing"] = CarregadorFaseJson._BRIEFINGS_ANTIGOS_DO_EXEMPLO[0]
	antigo.erase("versao_do_exemplo")
	var id_original: String = String(antigo["id_fase"])
	var caminho: String = _gravar_exemplo(antigo)

	CarregadorFaseJson.atualizar_exemplo()
	var depois_de_migrar: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	afirmar_verdadeiro(depois_de_migrar.get("mostrar_comandos") == true, "o exemplo antigo passa a mostrar")
	afirmar_contem(String(depois_de_migrar["briefing"]), "trocar senha", "o briefing ganha os comandos")
	afirmar_igual(String(depois_de_migrar["id_fase"]), id_original,
		"o id_fase nao muda: a telemetria ja coletada continua ligada")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))


func teste_exemplo_editado_pelo_professor_nao_e_tocado() -> void:
	var editado: Dictionary = CarregadorFaseJson._exemplo()
	editado.erase("mostrar_comandos")
	editado.erase("versao_do_exemplo")
	editado["briefing"] = "briefing que o professor reescreveu"
	var caminho: String = _gravar_exemplo(editado)

	CarregadorFaseJson.atualizar_exemplo()
	var lido: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	afirmar_igual(String(lido["briefing"]), "briefing que o professor reescreveu",
		"exemplo editado fica como o professor deixou")
	afirmar_falso(lido.has("mostrar_comandos"), "sem campo novo enfiado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
