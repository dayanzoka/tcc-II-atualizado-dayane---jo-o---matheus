extends CasoDeTeste

## Telemetria por fase: cada id_fase tem a sua telemetria, jogar a mesma fase de
## novo soma na mesma linha, e a media pode ser tirada so de algumas fases.
##
## Tres camadas: a agregacao (ResumoTelemetria, logica pura), o historico local
## do modo HTTP (Telemetria) e a tela (os tres niveis do dashboard).

const FASE_A: String = "aaaaaaaa-1111-4111-8111-111111111111"
const FASE_B: String = "bbbbbbbb-2222-4222-8222-222222222222"


class TransporteQueAceita extends TransporteTelemetria:
	## Faz o papel do servidor HTTP respondendo 2xx, sem rede.
	func rotulo() -> String:
		return "ACEITA"

	func enviar(_pacote: Dictionary) -> ResultadoEnvio:
		await _ceder_quadro()
		return ResultadoEnvio.ok("aceito no teste")


var _tela: Control = null
var _lote_original: int = 0
var _intervalo_original: float = 0.0


func antes() -> void:
	_lote_original = ConfigJogo.tamanho_lote
	_intervalo_original = ConfigJogo.intervalo_envio_s
	ConfigJogo.tamanho_lote = 500
	ConfigJogo.intervalo_envio_s = 3600.0


func depois() -> void:
	if _tela != null and is_instance_valid(_tela):
		_tela.queue_free()
	_tela = null
	ConfigJogo.tamanho_lote = _lote_original
	ConfigJogo.intervalo_envio_s = _intervalo_original


# ---------------------------------------------------------------------------
# Montagem de registros no formato do JSONL
# ---------------------------------------------------------------------------

func _evento(sessao: String, id_fase: String, titulo: String, codigo: String,
		quando: String, payload: Dictionary = {}) -> Dictionary:
	return {"tipo_registro": "evento", "dados": {
		"id_sessao": sessao, "id_fase": id_fase, "titulo_fase": titulo,
		"tipo_evento": codigo, "ocorrido_em": quando, "payload": payload,
	}}


func _tentativa(sessao: String, id_fase: String, resultado: String, ms: int) -> Dictionary:
	return {"tipo_registro": "tentativa", "dados": {
		"id_sessao": sessao, "id_fase": id_fase, "titulo_fase": "",
		"resultado": resultado, "tempo_resposta_ms": ms, "ocorrido_em": "2026-09-25T10:00:30.000Z",
	}}


## Fase A jogada DUAS vezes (uma concluida em 60s, uma abandonada), fase B uma.
func _registros() -> Array[Dictionary]:
	return [
		_evento("s1", "", "", CatalogoEventos.SESSAO_INICIADA, "2026-09-25T10:00:00.000Z"),
		_evento("s1", FASE_A, "Senhas", CatalogoEventos.FASE_INICIADA, "2026-09-25T10:00:00.000Z"),
		_tentativa("s1", FASE_A, CatalogoResultados.ERRO_SEMANTICO, 4000),
		_tentativa("s1", FASE_A, CatalogoResultados.SUCESSO, 2000),
		_evento("s1", FASE_A, "Senhas", CatalogoEventos.JOGADOR_CAPTURADO, "2026-09-25T10:00:40.000Z"),
		_evento("s1", FASE_A, "Senhas", CatalogoEventos.DICA_SOLICITADA, "2026-09-25T10:00:45.000Z"),
		_evento("s1", FASE_A, "Senhas", CatalogoEventos.FASE_CONCLUIDA, "2026-09-25T10:01:00.000Z",
			{"pontuacao": 120, "capturas": 1}),
		_evento("s1", FASE_B, "Phishing", CatalogoEventos.FASE_INICIADA, "2026-09-25T10:02:00.000Z"),
		_tentativa("s1", FASE_B, CatalogoResultados.SUCESSO, 1000),
		_evento("s1", FASE_B, "Phishing", CatalogoEventos.FASE_CONCLUIDA, "2026-09-25T10:02:30.500Z",
			{"pontuacao": 80, "capturas": 0}),
		_evento("s2", FASE_A, "Senhas", CatalogoEventos.FASE_INICIADA, "2026-09-26T09:00:00.000Z"),
		_evento("s2", FASE_A, "Senhas", CatalogoEventos.FASE_ABANDONADA, "2026-09-26T09:00:10.000Z",
			{"pontuacao": 0, "capturas": 0}),
	]


# ---------------------------------------------------------------------------
# Agregacao
# ---------------------------------------------------------------------------

func teste_relogio_converte_o_proprio_formato() -> void:
	var inicio: int = Relogio.iso_para_unix_ms("2026-09-25T10:00:00.000Z")
	afirmar_igual(Relogio.iso_para_unix_ms("2026-09-25T10:01:00.250Z") - inicio, 60250,
		"diferenca em ms entre dois ocorrido_em")
	afirmar_igual(Relogio.iso_para_unix_ms("ontem"), -1, "texto invalido nao vira 1970")
	var agora: String = Relogio.agora_utc_iso()
	afirmar_verdadeiro(Relogio.iso_para_unix_ms(agora) > 0, "le o que agora_utc_iso() escreve")


func teste_cada_fase_tem_partidas_e_jogar_de_novo_soma_na_mesma_linha() -> void:
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(_registros())
	afirmar_tamanho(resumo.por_fase, 2, "duas fases, uma linha por id_fase")

	var a: ResumoTelemetria.ResumoDeFase = resumo.fase(FASE_A)
	if not afirmar_nao_nulo(a, "fase A encontrada pelo id"):
		return
	afirmar_igual(a.partidas.size(), 2, "a mesma fase jogada duas vezes: duas partidas na MESMA linha")
	afirmar_igual(a.concluidas(), 1, "uma concluida")
	afirmar_igual(a.abandonadas(), 1, "uma abandonada")
	afirmar_proximo(a.taxa_de_conclusao(), 0.5, 0.001, "conclusao de 50%")
	afirmar_proximo(a.tempo_medio_de_conclusao_ms(), 60000.0, 0.1,
		"tempo de conclusao = FASE_CONCLUIDA - FASE_INICIADA da mesma sessao")
	afirmar_igual(a.melhor_pontuacao(), 120, "pontuacao vem do payload de FASE_CONCLUIDA")
	afirmar_igual(a.capturas, 1, "capturas contadas por JOGADOR_CAPTURADO")
	afirmar_igual(a.dicas, 1, "dicas contadas por DICA_SOLICITADA")
	afirmar_igual(a.acertos, 1, "acertos da fase")
	afirmar_igual(a.erros, 1, "erros da fase")
	afirmar_igual(a.ultima_vez, "2026-09-26T09:00:10.000Z", "ultima vez = registro mais recente")
	afirmar_igual(resumo.por_fase[0].id_fase, FASE_A, "a fase mais jogada vem primeiro")


func teste_media_so_das_fases_selecionadas() -> void:
	var geral: ResumoTelemetria = ResumoTelemetria.de_registros(_registros())
	afirmar_igual(geral.total_de_partidas(), 3, "sem filtro: todas as partidas")
	afirmar_igual(geral.tentativas(), 3, "sem filtro: todas as respostas")
	afirmar_igual(geral.sessoes, 2, "duas sessoes")

	var so_b: ResumoTelemetria = ResumoTelemetria.de_registros(_registros(), PackedStringArray([FASE_B]))
	afirmar_tamanho(so_b.por_fase, 1, "filtro deixa so a fase escolhida")
	afirmar_igual(so_b.total_de_partidas(), 1, "partidas so da fase B")
	afirmar_proximo(so_b.taxa_de_acerto(), 1.0, 0.001, "a media de B nao mistura os erros de A")
	afirmar_proximo(so_b.tempo_medio_de_conclusao_ms(), 30500.0, 0.1, "tempo so de B")
	afirmar_igual(so_b.sessoes, 1, "so as sessoes que jogaram B")

	var exportado: Dictionary = so_b.para_dicionario()
	afirmar_igual(Array(exportado["filtro_id_fases"]), [FASE_B], "o export diz qual filtro gerou os numeros")


func teste_titulo_atual_substitui_o_gravado() -> void:
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(_registros())
	resumo.aplicar_titulos({FASE_A: "Senhas fortes (v2)"})
	afirmar_igual(resumo.fase(FASE_A).rotulo(), "Senhas fortes (v2)",
		"fase renomeada no editor: mesmo id_fase, titulo novo")
	afirmar_igual(resumo.fase(FASE_B).rotulo(), "Phishing", "sem titulo novo, fica o da telemetria")


func teste_registros_crus_de_uma_fase() -> void:
	var so_a: Array[Dictionary] = ResumoTelemetria.registros_da_fase(_registros(), FASE_A)
	afirmar_igual(so_a.size(), 8, "todos os registros com id_fase A, nenhum de B nem de sessao")


# ---------------------------------------------------------------------------
# Historico local no modo HTTP
# ---------------------------------------------------------------------------

func teste_modo_http_guarda_copia_local_do_que_foi_aceito() -> void:
	var fila: String = caminho_temporario("fila_http_historico.json")
	var historico: String = caminho_temporario(Telemetria.NOME_HISTORICO_LOCAL)
	if FileAccess.file_exists(historico):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(historico))

	Telemetria.reiniciar(TransporteQueAceita.new(), fila)
	afirmar_igual(Telemetria.caminho_do_registro_local(), historico,
		"em HTTP o registro local e o historico ao lado da fila (nunca o real, nos testes)")

	Sessao.iniciar()
	Sessao.entrar_na_fase(1, 3, FASE_A, "Senhas")
	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {}, 1)
	Sessao.sair_da_fase()
	Sessao.encerrar()
	await Telemetria.descarregar()

	var registros: Array[Dictionary] = ResumoTelemetria.ler_jsonl(historico)
	var codigos: Array[String] = []
	for registro: Dictionary in registros:
		codigos.append(String((registro["dados"] as Dictionary).get("tipo_evento", "")))
	afirmar_verdadeiro(codigos.has(CatalogoEventos.FASE_INICIADA),
		"o evento aceito pelo servidor tambem ficou no historico local")
	afirmar_verdadeiro(Telemetria.fila_vazia(), "e saiu da fila (sem reenvio duplicado)")
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(registros)
	afirmar_nao_nulo(resumo.fase(FASE_A), "o painel de fases enxerga a partida do modo HTTP")


# ---------------------------------------------------------------------------
# Tela
# ---------------------------------------------------------------------------

func _preparar_registro_local(nome: String) -> void:
	var caminho: String = caminho_temporario(nome)
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	for registro: Dictionary in _registros():
		arquivo.store_line(JSON.stringify(registro))
	arquivo.close()
	Telemetria.reiniciar(TransporteMock.new(caminho), caminho_temporario("fila_%s.json" % nome))


func _abrir_tela() -> Control:
	_tela = (load("res://cenas/ui/dashboard_telemetria.tscn") as PackedScene).instantiate() as Control
	add_child(_tela)
	# _ready espera a descarga (um quadro do transporte) antes de ler o arquivo.
	for i: int in 3:
		await get_tree().process_frame
	return _tela


func teste_tela_lista_fases_jogadas_e_abre_o_detalhe_por_id() -> void:
	_preparar_registro_local("tela_fases.jsonl")
	var tela: Control = await _abrir_tela()

	afirmar_contem((tela.get_node("Raiz/Margem/Coluna/Cabecalho") as Label).text, "todas as fases",
		"a tela abre na visao geral, com a media de todas as fases")

	tela._ao_abrir_fases()
	var lista: ItemList = tela.get_node("PainelFases/Margem/Coluna/Lista") as ItemList
	afirmar_verdadeiro((tela.get_node("PainelFases") as Control).visible, "o botao abre as fases jogadas")
	afirmar_igual(lista.select_mode, ItemList.SELECT_MULTI, "da para escolher varias fases")
	afirmar_igual(lista.item_count, 2, "uma linha por fase jogada")
	afirmar_igual(String(lista.get_item_metadata(0)), FASE_A, "cada linha carrega o id_fase")

	lista.select(0)
	tela._ao_ver_fase_selecionada()
	afirmar_verdadeiro((tela.get_node("PainelDetalhe") as Control).visible, "o detalhe abre")
	var detalhe: String = (tela.get_node("PainelDetalhe/Margem/Coluna/Detalhe") as RichTextLabel).get_parsed_text()
	afirmar_contem(detalhe, "partidas: 2", "o detalhe e da fase A: duas partidas")
	afirmar_contem(detalhe, "abandonada", "com o historico de partidas")

	tela._ao_exportar_fase_aberta()
	var exportado: String = "user://exportacoes/telemetria_fase_%s.json" % FASE_A.substr(0, 8)
	afirmar_verdadeiro(FileAccess.file_exists(exportado), "exportar esta fase grava o arquivo")
	var corpo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(exportado)) as Dictionary
	afirmar_igual(String((corpo["resumo"] as Dictionary)["id_fase"]), FASE_A, "export da fase certa")
	afirmar_igual((corpo["registros"] as Array).size(), 8, "com os registros crus da fase")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(exportado))


func teste_tela_media_das_selecionadas_e_volta_para_todas() -> void:
	_preparar_registro_local("tela_media.jsonl")
	var tela: Control = await _abrir_tela()
	var cabecalho: Label = tela.get_node("Raiz/Margem/Coluna/Cabecalho") as Label
	var limpar: Button = tela.get_node("Raiz/Margem/Coluna/Acoes/LimparFiltro") as Button
	afirmar_falso(limpar.visible, "sem filtro, sem botao de limpar")

	tela._ao_abrir_fases()
	var lista: ItemList = tela.get_node("PainelFases/Margem/Coluna/Lista") as ItemList
	lista.select(1)  # so a fase B
	tela._ao_calcular_media_das_selecionadas()

	afirmar_falso((tela.get_node("PainelFases") as Control).visible, "volta para a visao geral")
	afirmar_contem(cabecalho.text, "1 fase(s) selecionada(s)", "o cabecalho diz que e media filtrada")
	afirmar_contem(cabecalho.text, "1 partida(s)", "so as partidas da fase B")
	afirmar_verdadeiro(limpar.visible, "com filtro, aparece o botao para voltar a todas")

	tela._ao_limpar_filtro()
	afirmar_contem(cabecalho.text, "todas as fases", "limpar volta para a media geral")
	afirmar_contem(cabecalho.text, "3 partida(s)", "com todas as partidas")


# ---------------------------------------------------------------------------
# Regressao: registro legado/malformado derrubava o painel inteiro
# ---------------------------------------------------------------------------

## Linhas que ja existem de verdade no registro local de quem jogou versoes
## antigas (antes do id_fase), ou que um processo morto cortou. Antes da
## correcao, "dados": null fazia `as Dictionary` lancar erro, o resumo ficava
## nulo e o painel parava -- no editor, o jogo travava no depurador.
func _registros_hostis() -> Array[Dictionary]:
	var hostis: Array[Dictionary] = [
		{"tipo_registro": "evento", "dados": null},
		{"tipo_registro": "evento", "dados": [1, 2, 3]},
		{"tipo_registro": "evento", "dados": {"id_sessao": null, "tipo_evento": "FASE_INICIADA",
			"id_fase": null, "titulo_fase": null, "ocorrido_em": null, "payload": null}},
		{"tipo_registro": "evento", "dados": {"id_sessao": "s9", "tipo_evento": "FASE_CONCLUIDA",
			"id_fase": FASE_B, "ocorrido_em": 12345, "payload": [1]}},
		{"tipo_registro": "tentativa", "dados": {"id_sessao": "s9", "id_fase": FASE_B,
			"resultado": null, "tempo_resposta_ms": "abc"}},
		{"tipo_registro": "tentativa", "dados": {"id_sessao": "s9", "id_fase": FASE_B,
			"resultado": "SUCESSO", "tempo_resposta_ms": "1500"}},
		{"tipo_registro": null, "dados": {}},
	]
	return hostis


func teste_registro_malformado_nao_derruba_a_agregacao() -> void:
	var registros: Array[Dictionary] = _registros()
	registros.append_array(_registros_hostis())
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(registros)
	if not afirmar_nao_nulo(resumo, "o resumo existe mesmo com lixo no registro"):
		return
	afirmar_igual(resumo.fase(FASE_A).partidas.size(), 2, "as fases boas continuam certas")
	var b: ResumoTelemetria.ResumoDeFase = resumo.fase(FASE_B)
	afirmar_igual(b.acertos, 2, "tempo como texto numerico ainda conta a resposta")
	afirmar_igual(b.partidas.size(), 2, "fim sem inicio ainda e uma partida")
	afirmar_nao_nulo(ResumoTelemetria.de_registros(registros, PackedStringArray([FASE_B])),
		"o filtro tambem aguenta")


func teste_jsonl_com_linha_cortada_e_lixo_e_lido_sem_erro() -> void:
	var caminho: String = caminho_temporario("registro_hostil.jsonl")
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	for registro: Dictionary in _registros():
		arquivo.store_line(JSON.stringify(registro))
	arquivo.store_line("[1, 2]")
	arquivo.store_line("texto solto")
	arquivo.store_string('{"tipo_registro": "evento", "dados": {"id_sess')
	arquivo.close()

	var lidos: Array[Dictionary] = ResumoTelemetria.ler_jsonl(caminho)
	afirmar_igual(lidos.size(), _registros().size(), "so as linhas que sao objeto JSON entram")


func teste_tela_abre_com_registro_hostil() -> void:
	var caminho: String = caminho_temporario("tela_hostil.jsonl")
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	var todos: Array[Dictionary] = _registros()
	todos.append_array(_registros_hostis())
	for registro: Dictionary in todos:
		arquivo.store_line(JSON.stringify(registro))
	arquivo.close()
	Telemetria.reiniciar(TransporteMock.new(caminho), caminho_temporario("fila_tela_hostil.json"))

	var tela: Control = await _abrir_tela()
	afirmar_contem((tela.get_node("Raiz/Margem/Coluna/Cabecalho") as Label).text, "partida(s)",
		"a visao geral carregou")
	tela._ao_abrir_fases()
	var lista: ItemList = tela.get_node("PainelFases/Margem/Coluna/Lista") as ItemList
	afirmar_igual(lista.item_count, 2, "as duas fases boas aparecem na lista")
