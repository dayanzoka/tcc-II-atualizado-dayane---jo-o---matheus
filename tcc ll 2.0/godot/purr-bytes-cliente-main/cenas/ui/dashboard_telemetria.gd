extends Control

## Dashboard de Telemetria -- a tela da Figura 7 da monografia.
##
## Tres niveis, do geral para o especifico:
##
##   1. VISAO GERAL (Raiz): as medias de todas as fases jogadas -- ou so das
##      fases escolhidas, quando ha filtro. E a tela que abre.
##   2. FASES JOGADAS (PainelFases): uma linha por id_fase. Selecao multipla
##      (ItemList em SELECT_MULTI) para tirar a media so de algumas fases ou
##      exportar so elas.
##   3. DETALHE DA FASE (PainelDetalhe): a telemetria de UM id_fase, com o
##      historico de partidas. Jogar a mesma fase de novo soma aqui, porque a
##      identidade da fase e o id_fase, nao o titulo nem o numero.
##
## As fases sao rotuladas pelo titulo ATUAL (lido de user://fases por id_fase),
## nunca "Nivel 1" e "Nivel 2" fixos: como as fases sao criadas livremente,
## rotulo fixo mentiria na primeira fase nova.
##
## FONTE DOS DADOS: o registro local da coleta (Telemetria.
## caminho_do_registro_local): o JSONL do modo MOCK, ou a copia local do que o
## modo HTTP ja entregou ao servidor.

const CENA_DO_MENU: String = "res://cenas/ui/menu_principal.tscn"
const CAMINHO_DA_EXPORTACAO: String = "user://resumo_telemetria.json"
const PASTA_DE_EXPORTACAO: String = "user://exportacoes"

## As quatro cores do grafico foram clareadas junto com o resto do painel:
## dashboard_telemetria.tscn passou a ter fundo escuro (tema_telas_secundarias,
## ver ADR 0017 adendo), e as cores antigas (tuned para fundo branco/creme)
## ficariam ilegiveis desenhadas por cima do painel escuro no _draw() abaixo.
const COR_ACERTO: Color = Color(0.42, 0.78, 0.48)
const COR_ERRO: Color = Color(0.92, 0.42, 0.38)
const COR_EIXO: Color = Color(0.69, 0.729, 0.859)
const COR_TEXTO: Color = Color(0.937, 0.945, 0.973)

@onready var _grafico: Control = $Raiz/Margem/Coluna/Corpo/Grafico
@onready var _tabela: RichTextLabel = $Raiz/Margem/Coluna/Corpo/Tabela
@onready var _cabecalho: Label = $Raiz/Margem/Coluna/Cabecalho
@onready var _rodape: Label = $Raiz/Margem/Coluna/Rodape
@onready var _botao_limpar_filtro: Button = $Raiz/Margem/Coluna/Acoes/LimparFiltro
@onready var _painel_diagnostico: PanelContainer = $PainelDiagnostico
@onready var _diagnostico: RichTextLabel = $PainelDiagnostico/Margem/Coluna/Diagnostico

@onready var _painel_fases: PanelContainer = $PainelFases
@onready var _lista_fases: ItemList = $PainelFases/Margem/Coluna/Lista
@onready var _aviso_fases: Label = $PainelFases/Margem/Coluna/Aviso

@onready var _painel_detalhe: PanelContainer = $PainelDetalhe
@onready var _titulo_detalhe: Label = $PainelDetalhe/Margem/Coluna/Titulo
@onready var _texto_detalhe: RichTextLabel = $PainelDetalhe/Margem/Coluna/Detalhe
@onready var _aviso_detalhe: Label = $PainelDetalhe/Margem/Coluna/Aviso

## Todas as linhas do registro local, lidas uma vez por "atualizar".
var _registros: Array[Dictionary] = []
## Sem filtro: e dele que sai a lista de fases jogadas.
var _resumo_completo: ResumoTelemetria = ResumoTelemetria.new()
## O que a visao geral mostra (com o filtro aplicado, se houver).
var _resumo: ResumoTelemetria = ResumoTelemetria.new()
var _filtro: PackedStringArray = PackedStringArray()
var _titulos: Dictionary = {}
var _fase_aberta: String = ""


func _ready() -> void:
	$Raiz/Margem/Coluna/Acoes/Atualizar.pressed.connect(_carregar)
	$Raiz/Margem/Coluna/Acoes/FasesJogadas.pressed.connect(_ao_abrir_fases)
	$Raiz/Margem/Coluna/Acoes/Exportar.pressed.connect(_ao_exportar)
	_botao_limpar_filtro.pressed.connect(_ao_limpar_filtro)
	$Raiz/Margem/Coluna/Acoes/Diagnostico.pressed.connect(_ao_abrir_diagnostico)
	$Raiz/Margem/Coluna/Acoes/Voltar.pressed.connect(_ao_voltar)
	$PainelDiagnostico/Margem/Coluna/Fechar.pressed.connect(_ao_fechar_diagnostico)

	$PainelFases/Margem/Coluna/Acoes/VerFase.pressed.connect(_ao_ver_fase_selecionada)
	$PainelFases/Margem/Coluna/Acoes/Media.pressed.connect(_ao_calcular_media_das_selecionadas)
	$PainelFases/Margem/Coluna/Acoes/ExportarSelecionadas.pressed.connect(_ao_exportar_selecionadas)
	$PainelFases/Margem/Coluna/Acoes/Fechar.pressed.connect(_ao_fechar_fases)
	# Duplo clique / Enter na linha abre a fase: atalho nativo do ItemList.
	_lista_fases.item_activated.connect(func(indice: int) -> void:
		_abrir_detalhe(String(_lista_fases.get_item_metadata(indice))))

	$PainelDetalhe/Margem/Coluna/Acoes/ExportarFase.pressed.connect(_ao_exportar_fase_aberta)
	$PainelDetalhe/Margem/Coluna/Acoes/VoltarAsFases.pressed.connect(_ao_fechar_detalhe)

	_grafico.draw.connect(_desenhar_grafico)

	_painel_diagnostico.visible = false
	_painel_fases.visible = false
	_painel_detalhe.visible = false
	$Raiz/Margem/Coluna/Acoes/Voltar.grab_focus()
	await _carregar()


# ---------------------------------------------------------------------------
# Dados
# ---------------------------------------------------------------------------

func _carregar() -> void:
	# Drena a fila ANTES de ler: sem isso a partida que acabou de terminar (ainda
	# em memoria ate o proximo tique do temporizador) nao apareceria no painel.
	await Telemetria.descarregar()

	var caminho: String = Telemetria.caminho_do_registro_local()
	_registros = ResumoTelemetria.ler_jsonl(caminho)
	_titulos = CarregadorFaseJson.titulos_por_id()
	_resumo_completo = ResumoTelemetria.de_registros(_registros)
	_resumo_completo.aplicar_titulos(_titulos)

	# Filtro de uma fase que sumiu do registro nao pode ficar preso na tela.
	var validos := PackedStringArray()
	for id_fase: String in _filtro:
		if _resumo_completo.fase(id_fase) != null:
			validos.append(id_fase)
	_filtro = validos

	_recalcular_visao_geral()
	if caminho.is_empty():
		_cabecalho.text = "sem transporte de telemetria configurado."
	if _painel_fases.visible:
		_montar_lista_de_fases()
	if _painel_detalhe.visible:
		_abrir_detalhe(_fase_aberta)


func _recalcular_visao_geral() -> void:
	_resumo = ResumoTelemetria.de_registros(_registros, _filtro)
	_resumo.aplicar_titulos(_titulos)
	_botao_limpar_filtro.visible = not _filtro.is_empty()

	var escopo: String = "todas as fases" if _filtro.is_empty() \
		else "media de %d fase(s) selecionada(s)" % _filtro.size()
	if _resumo.vazio():
		_cabecalho.text = "nenhuma partida registrada ainda -- jogue uma fase e volte aqui."
	else:
		_cabecalho.text = "%s - %d sessao(oes) - %d partida(s) - %.0f%% de acerto" % [
			escopo, _resumo.sessoes, _resumo.total_de_partidas(), _resumo.taxa_de_acerto() * 100.0]

	_montar_tabela()
	_grafico.queue_redraw()


## Rotulo de uma fase pelo id -- usado na lista e no detalhe.
func _rotulo(id_fase: String) -> String:
	var item: ResumoTelemetria.ResumoDeFase = _resumo_completo.fase(id_fase)
	return item.rotulo() if item != null else "fase %s" % id_fase.substr(0, 8)


# ---------------------------------------------------------------------------
# Visao geral
# ---------------------------------------------------------------------------

## Barras desenhadas a mao (e nao um addon de grafico) porque sao duas: o custo
## de uma dependencia nova nao se paga, e _draw da controle total sobre o
## contraste, que e o ponto fraco historico das telas deste projeto.
func _desenhar_grafico() -> void:
	var area: Vector2 = _grafico.size
	var fonte: Font = ThemeDB.fallback_font
	var altura_util: float = area.y - 24.0

	# Linha de base: sem ela, barra zerada e area vazia ficam iguais.
	_grafico.draw_line(Vector2(0, altura_util), Vector2(area.x, altura_util), COR_EIXO, 1.0)

	var total: int = maxi(1, maxi(_resumo.acertos, _resumo.erros))
	var largura_barra: float = minf(64.0, area.x / 4.0)
	var dados: Array[Dictionary] = [
		{"rotulo": "acertos", "valor": _resumo.acertos, "cor": COR_ACERTO},
		{"rotulo": "erros", "valor": _resumo.erros, "cor": COR_ERRO},
	]

	for i: int in dados.size():
		var valor: int = int(dados[i]["valor"])
		var altura: float = (float(valor) / float(total)) * (altura_util - 14.0)
		var x: float = area.x * 0.25 + float(i) * (area.x * 0.3) - largura_barra / 2.0
		var topo: float = altura_util - altura

		_grafico.draw_rect(Rect2(x, topo, largura_barra, altura), dados[i]["cor"])
		_grafico.draw_string(fonte, Vector2(x, topo - 3.0), str(valor),
			HORIZONTAL_ALIGNMENT_LEFT, largura_barra, 10, COR_TEXTO)
		_grafico.draw_string(fonte, Vector2(x, altura_util + 12.0), String(dados[i]["rotulo"]),
			HORIZONTAL_ALIGNMENT_LEFT, largura_barra + 20.0, 9, COR_TEXTO)


func _montar_tabela() -> void:
	var linhas: PackedStringArray = PackedStringArray([
		"[b]medias[/b]",
		"acerto: %.0f%%  |  resposta media: %.1fs" % [
			_resumo.taxa_de_acerto() * 100.0, _resumo.tempo_medio_de_resposta_ms() / 1000.0],
		"conclusao: %.0f%% (%d de %d)  |  tempo medio: %.1fs" % [
			_resumo.taxa_de_conclusao() * 100.0, _resumo.total_concluidas(),
			_resumo.total_concluidas() + _resumo.total_abandonadas(),
			_resumo.tempo_medio_de_conclusao_ms() / 1000.0],
		"pontuacao media: %.0f  |  capturas/partida: %.1f  |  dicas: %d" % [
			_resumo.pontuacao_media(), _resumo.capturas_por_partida(), _resumo.total_dicas()],
		"",
		"[b]por fase[/b]",
	])

	if _resumo.por_fase.is_empty():
		linhas.append("sem partidas registradas.")
	else:
		# [table] do RichTextLabel alinha as colunas com a fonte proporcional do
		# tema, o que o alinhamento por espacos (%-20s) nao consegue.
		var celulas: PackedStringArray = PackedStringArray([
			_cabecalho_de_tabela(["fase", "partidas", "acerto", "tempo med."])])
		for fase: ResumoTelemetria.ResumoDeFase in _resumo.por_fase:
			celulas.append(_linha_de_tabela([
				fase.rotulo().substr(0, 24),
				str(fase.partidas.size()),
				"%.0f%%" % (fase.taxa_de_acerto() * 100.0),
				"%.1fs" % (fase.tempo_medio_de_conclusao_ms() / 1000.0),
			]))
		linhas.append("[table=4]%s[/table]" % "".join(celulas))

	_tabela.clear()
	_tabela.append_text("\n".join(linhas))


func _ao_limpar_filtro() -> void:
	_filtro = PackedStringArray()
	_recalcular_visao_geral()
	_rodape.text = "mostrando a media de todas as fases."


func _ao_exportar() -> void:
	await _carregar()
	_rodape.text = _gravar_json(CAMINHO_DA_EXPORTACAO, _resumo.para_dicionario())


# ---------------------------------------------------------------------------
# Fases jogadas
# ---------------------------------------------------------------------------

func _ao_abrir_fases() -> void:
	_montar_lista_de_fases()
	_aviso_fases.text = "selecione uma ou mais fases (ctrl/shift para varias). duplo clique abre a fase."
	_painel_fases.visible = true
	_lista_fases.grab_focus()


func _ao_fechar_fases() -> void:
	_painel_fases.visible = false
	$Raiz/Margem/Coluna/Acoes/FasesJogadas.grab_focus()


func _montar_lista_de_fases() -> void:
	_lista_fases.clear()
	for fase: ResumoTelemetria.ResumoDeFase in _resumo_completo.por_fase:
		if fase.id_fase.is_empty():
			continue  # registro legado sem id: nao da para abrir nem filtrar
		var texto: String = "%s  -  %d partida(s)  -  %.0f%% acerto  -  %d concluida(s)" % [
			fase.rotulo(), fase.partidas.size(), fase.taxa_de_acerto() * 100.0, fase.concluidas()]
		var indice: int = _lista_fases.add_item(texto)
		_lista_fases.set_item_metadata(indice, fase.id_fase)
		_lista_fases.set_item_tooltip(indice, "id_fase: %s" % fase.id_fase)
		if _filtro.has(fase.id_fase):
			_lista_fases.select(indice, false)
	if _lista_fases.item_count == 0:
		_aviso_fases.text = "nenhuma fase jogada ainda."


func ids_selecionados() -> PackedStringArray:
	var ids := PackedStringArray()
	for indice: int in _lista_fases.get_selected_items():
		ids.append(String(_lista_fases.get_item_metadata(indice)))
	return ids


func _ao_ver_fase_selecionada() -> void:
	var ids: PackedStringArray = ids_selecionados()
	if ids.is_empty():
		_aviso_fases.text = "selecione uma fase para ver a telemetria dela."
		return
	_abrir_detalhe(ids[0])


func _ao_calcular_media_das_selecionadas() -> void:
	var ids: PackedStringArray = ids_selecionados()
	if ids.is_empty():
		_aviso_fases.text = "selecione ao menos uma fase para tirar a media."
		return
	_filtro = ids
	_recalcular_visao_geral()
	_painel_fases.visible = false
	_rodape.text = "mostrando a media de %d fase(s) selecionada(s)." % ids.size()
	_botao_limpar_filtro.grab_focus()


func _ao_exportar_selecionadas() -> void:
	var ids: PackedStringArray = ids_selecionados()
	if ids.is_empty():
		_aviso_fases.text = "selecione ao menos uma fase para exportar."
		return
	await Telemetria.descarregar()
	var resumo: ResumoTelemetria = ResumoTelemetria.de_registros(_registros, ids)
	resumo.aplicar_titulos(_titulos)
	_aviso_fases.text = _gravar_json(
		PASTA_DE_EXPORTACAO.path_join("telemetria_selecao.json"), resumo.para_dicionario())


# ---------------------------------------------------------------------------
# Detalhe de uma fase
# ---------------------------------------------------------------------------

func _abrir_detalhe(id_fase: String) -> void:
	var fase: ResumoTelemetria.ResumoDeFase = _resumo_completo.fase(id_fase)
	if fase == null:
		return
	_fase_aberta = id_fase
	_titulo_detalhe.text = fase.rotulo()
	_aviso_detalhe.text = "id_fase %s" % id_fase

	var linhas: PackedStringArray = PackedStringArray([
		"[b]partidas[/b]: %d  (concluidas %d, abandonadas %d)  -  conclusao %.0f%%" % [
			fase.partidas.size(), fase.concluidas(), fase.abandonadas(),
			fase.taxa_de_conclusao() * 100.0],
		"[b]tempo medio de conclusao[/b]: %.1fs  -  [b]pontuacao[/b] media %.0f, melhor %d" % [
			fase.tempo_medio_de_conclusao_ms() / 1000.0, fase.pontuacao_media(), fase.melhor_pontuacao()],
		"[b]respostas[/b]: %d acerto(s), %d erro(s)  -  %.0f%% acerto  -  resposta media %.1fs" % [
			fase.acertos, fase.erros, fase.taxa_de_acerto() * 100.0, fase.tempo_medio_ms() / 1000.0],
		"[b]capturas[/b]: %d  -  [b]dicas[/b]: %d  -  ultima vez: %s" % [
			fase.capturas, fase.dicas, fase.ultima_vez.substr(0, 16).replace("T", " ")],
		"",
		"[b]historico de partidas[/b]",
	])
	if fase.partidas.is_empty():
		linhas.append("nenhuma partida iniciada (so respostas avulsas registradas).")
	else:
		var celulas: PackedStringArray = PackedStringArray([_cabecalho_de_tabela(
			["#", "inicio (UTC)", "resultado", "duracao", "pontos", "capturas"])])
		for i: int in range(fase.partidas.size() - 1, -1, -1):  # mais recente primeiro
			var partida: ResumoTelemetria.Partida = fase.partidas[i]
			celulas.append(_linha_de_tabela([
				str(i + 1),
				partida.iniciada_em.substr(0, 16).replace("T", " "),
				partida.resultado.to_lower().replace("_", " "),
				"--" if partida.duracao_ms < 0 else "%.1fs" % (partida.duracao_ms / 1000.0),
				str(partida.pontuacao),
				str(partida.capturas),
			]))
		linhas.append("[table=6]%s[/table]" % "".join(celulas))

	_texto_detalhe.clear()
	_texto_detalhe.append_text("\n".join(linhas))
	_painel_detalhe.visible = true
	$PainelDetalhe/Margem/Coluna/Acoes/ExportarFase.grab_focus()


func _ao_fechar_detalhe() -> void:
	_painel_detalhe.visible = false
	if _painel_fases.visible:
		_lista_fases.grab_focus()


func _ao_exportar_fase_aberta() -> void:
	var fase: ResumoTelemetria.ResumoDeFase = _resumo_completo.fase(_fase_aberta)
	if fase == null:
		return
	# Resumo + registros crus: quem analisa quer poder recalcular, nao so
	# confiar na media que a tela fez.
	var corpo: Dictionary = {
		"gerado_em": Relogio.agora_utc_iso(),
		"resumo": fase.para_dicionario(),
		"registros": ResumoTelemetria.registros_da_fase(_registros, _fase_aberta),
	}
	_aviso_detalhe.text = _gravar_json(
		PASTA_DE_EXPORTACAO.path_join("telemetria_fase_%s.json" % _fase_aberta.substr(0, 8)), corpo)


# ---------------------------------------------------------------------------
# Comum
# ---------------------------------------------------------------------------

func _cabecalho_de_tabela(titulos: Array) -> String:
	var saida: String = ""
	for titulo: Variant in titulos:
		saida += "[cell][b]%s[/b]  [/cell]" % String(titulo)
	return saida


## Texto vindo do registro (titulo da fase) passa por escape: um "[" num titulo
## seria lido como tag de BBCode e quebraria a tabela.
func _linha_de_tabela(valores: Array) -> String:
	var saida: String = ""
	for valor: Variant in valores:
		saida += "[cell]%s  [/cell]" % String(valor).replace("[", "[lb]")
	return saida

## Devolve a mensagem para a tela (sucesso com o caminho real, ou o erro).
func _gravar_json(caminho: String, dados: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		return "falha ao escrever %s (erro %d)" % [caminho, FileAccess.get_open_error()]
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.close()
	return "exportado para %s" % ProjectSettings.globalize_path(caminho)


func _ao_abrir_diagnostico() -> void:
	var config: Dictionary = ConfigJogo.resumo_seguro()
	var fila: Dictionary = Telemetria.estatisticas()

	var linhas: PackedStringArray = PackedStringArray([
		"[b]configuracao[/b]",
		"modo: %s" % config["modo_telemetria"],
		"url: %s" % config["url_api"],
		"chave definida: %s" % ("sim" if bool(config["chave_api_definida"]) else "nao"),
		"id_sujeito: %s" % config["id_sujeito"],
		"versao: %s | plataforma: %s" % [config["versao_jogo"], config["plataforma"]],
		"registro local: %s" % Telemetria.caminho_do_registro_local(),
		"",
		"[b]fila[/b]",
		"transporte: %s" % fila["transporte"],
		"sessao: %s" % ("aberta" if bool(fila["sessao_aberta"]) else "fechada"),
		"proxima sequencia: %d" % int(fila["proxima_sequencia"]),
		"eventos na fila: %d" % int(fila["eventos_na_fila"]),
		"tentativas na fila: %d" % int(fila["tentativas_na_fila"]),
		"falhas consecutivas: %d" % int(fila["falhas_consecutivas"]),
		"itens descartados: %d" % int(fila["itens_descartados"]),
	])

	_diagnostico.clear()
	_diagnostico.append_text("\n".join(linhas))
	_painel_diagnostico.visible = true
	$PainelDiagnostico/Margem/Coluna/Fechar.grab_focus()


func _ao_fechar_diagnostico() -> void:
	_painel_diagnostico.visible = false
	$Raiz/Margem/Coluna/Acoes/Diagnostico.grab_focus()


func _ao_voltar() -> void:
	get_tree().change_scene_to_file(CENA_DO_MENU)
