extends CasoDeTeste

## Dashboard de Telemetria: a agregacao (ResumoTelemetria) e a tela.
##
## A agregacao e testada sem abrir a cena porque ela e logica pura -- mesma
## divisao de DemonstracaoCifra. A tela entra num teste so, para garantir que
## carrega, que o fundo e opaco (o bug historico de painel transparente) e que
## o diagnostico tecnico continua acessivel de dentro dela.


func _registro(tipo: String, dados: Dictionary) -> Dictionary:
	return {"tipo_registro": tipo, "dados": dados}


func _tentativa(id_fase: String, titulo: String, resultado: String, ms: int) -> Dictionary:
	return _registro("tentativa", {
		"id_sessao": "sessao-1",
		"id_fase": id_fase,
		"titulo_fase": titulo,
		"resultado": resultado,
		"tempo_resposta_ms": ms,
	})


func teste_conta_acertos_e_erros() -> void:
	var registros: Array[Dictionary] = [
		_tentativa("f-1", "Cesar", CatalogoResultados.SUCESSO, 1000),
		_tentativa("f-1", "Cesar", CatalogoResultados.ERRO_SEMANTICO, 2000),
		_tentativa("f-1", "Cesar", CatalogoResultados.ERRO_LEXICO, 3000),
	]
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(registros)

	afirmar_igual(resumo.acertos, 1, "um acerto")
	afirmar_igual(resumo.erros, 2, "dois erros, de tipos diferentes")
	afirmar_proximo(resumo.taxa_de_acerto(), 1.0 / 3.0, 0.001, "taxa de acerto de 1/3")


func teste_abandono_nao_conta_como_erro() -> void:
	var registros: Array[Dictionary] = [
		_tentativa("f-1", "Cesar", CatalogoResultados.SUCESSO, 1000),
		_tentativa("f-1", "Cesar", CatalogoResultados.ABANDONO, 0),
	]
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(registros)

	afirmar_igual(resumo.erros, 0,
		"desistir nao e errar: contar ABANDONO como erro misturaria dois fenomenos")
	afirmar_igual(resumo.tentativas(), 1, "so a tentativa respondida entra na conta")


func teste_agrupa_por_id_fase_e_calcula_tempo_medio() -> void:
	var registros: Array[Dictionary] = [
		_tentativa("f-1", "Cesar", CatalogoResultados.SUCESSO, 1000),
		_tentativa("f-1", "Cesar", CatalogoResultados.SUCESSO, 3000),
		_tentativa("f-2", "Vigenere", CatalogoResultados.ERRO_SEMANTICO, 5000),
	]
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(registros)

	afirmar_tamanho(resumo.por_fase, 2, "duas fases distintas")
	# Ordenado por numero de tentativas: f-1 primeiro.
	afirmar_igual(resumo.por_fase[0].id_fase, "f-1", "a fase mais exercitada vem primeiro")
	afirmar_proximo(resumo.por_fase[0].tempo_medio_ms(), 2000.0, 0.1, "media de 1000 e 3000")
	afirmar_igual(resumo.por_fase[1].rotulo(), "Vigenere", "o rotulo usa o titulo da fase")


func teste_fases_diferentes_com_o_mesmo_numero_nao_se_misturam() -> void:
	# O caso que motivou o id_fase: duas fases criadas livremente podem ter o
	# mesmo numero. Agrupar por numero somaria as duas na mesma linha.
	var registros: Array[Dictionary] = [
		_tentativa("f-alpha", "Fase do professor A", CatalogoResultados.SUCESSO, 1000),
		_tentativa("f-beta", "Fase do professor B", CatalogoResultados.ERRO_SEMANTICO, 4000),
	]
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(registros)

	afirmar_tamanho(resumo.por_fase, 2, "cada id_fase e uma linha propria")


func teste_rotulo_sem_titulo_cai_no_id_abreviado() -> void:
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros([
		_tentativa("abcdef0123456789", "", CatalogoResultados.SUCESSO, 100),
	])
	afirmar_igual(resumo.por_fase[0].rotulo(), "fase abcdef01",
		"sem titulo, o rotulo e o id abreviado -- nunca 'Nivel 1' fixo")


func teste_exportacao_tem_os_numeros_da_tela() -> void:
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros([
		_tentativa("f-1", "Cesar", CatalogoResultados.SUCESSO, 1000),
		_tentativa("f-1", "Cesar", CatalogoResultados.ERRO_LEXICO, 2000),
	])
	var exportado: Dictionary = resumo.para_dicionario()

	afirmar_igual(int(exportado["acertos"]), 1, "acertos no JSON exportado")
	afirmar_igual(int(exportado["erros"]), 1, "erros no JSON exportado")
	afirmar_tamanho(exportado["por_fase"], 1, "uma linha por fase")
	afirmar_verdacamente_json(exportado)


func afirmar_verdacamente_json(dados: Dictionary) -> void:
	# O export precisa sobreviver a serializacao: um valor nao serializavel
	# silenciosamente viraria null no arquivo.
	var texto: String = JSON.stringify(dados)
	var relido: Variant = JSON.parse_string(texto)
	afirmar_verdadeiro(typeof(relido) == TYPE_DICTIONARY,
		"o resumo exportado e JSON valido de ida e volta")


func teste_jsonl_inexistente_devolve_resumo_vazio() -> void:
	var registros: Array[Dictionary] = ResumoTelemetria.ler_jsonl(
		caminho_temporario("nao_existe.jsonl"))
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(registros)

	afirmar_verdadeiro(resumo.vazio(), "sem arquivo, o resumo e vazio e nao quebra a tela")
	afirmar_igual(resumo.taxa_de_acerto(), 0.0, "e a taxa nao divide por zero")


func teste_a_tela_carrega_com_fundo_opaco_e_diagnostico_acessivel() -> void:
	var cena: PackedScene = load("res://cenas/ui/dashboard_telemetria.tscn") as PackedScene
	if not afirmar_nao_nulo(cena, "a cena do dashboard carrega"):
		return

	var tela: Control = cena.instantiate() as Control
	add_child(tela)
	await get_tree().process_frame

	var fundo: ColorRect = tela.get_node("Fundo") as ColorRect
	afirmar_nao_nulo(fundo, "a tela tem fundo proprio")
	afirmar_igual(fundo.color.a, 1.0,
		"o fundo e OPACO: painel transparente sobre o jogo foi o bug historico das telas")

	var painel: PanelContainer = tela.get_node("Raiz") as PanelContainer
	var estilo: StyleBoxFlat = painel.get_theme_stylebox("panel") as StyleBoxFlat
	afirmar_nao_nulo(estilo, "o painel principal tem StyleBox proprio, nao o default do tema")
	afirmar_igual(estilo.bg_color.a, 1.0, "e ele tambem e opaco")

	var diagnostico: PanelContainer = tela.get_node("PainelDiagnostico") as PanelContainer
	afirmar_falso(diagnostico.visible, "o diagnostico tecnico comeca fechado")
	tela._ao_abrir_diagnostico()
	afirmar_verdadeiro(diagnostico.visible,
		"...e continua acessivel de dentro do dashboard: nenhum recurso foi perdido")

	tela.queue_free()
	await get_tree().process_frame
