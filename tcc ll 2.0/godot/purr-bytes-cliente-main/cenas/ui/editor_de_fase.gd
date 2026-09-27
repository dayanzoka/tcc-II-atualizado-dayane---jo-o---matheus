extends Control

## Editor visual de fases: monta uma fase e grava como .json em user://fases.
##
## O editor NAO tem modelo de dados proprio. Ele preenche o FaseConfig que o
## jogo ja usa e delega a validacao para FaseConfig.problemas() e
## CarregadorFaseJson -- as mesmas funcoes que rodam ao carregar a fase. Se o
## editor validasse por conta propria, existiriam duas nocoes de "fase valida"
## e elas divergiriam no primeiro campo novo.
##
## As listas de vigias e de terminais sao construidas em codigo (e nao no
## .tscn) porque a quantidade e livre: o professor adiciona e remove enquanto
## monta. Cada linha carrega os seus proprios campos, e ler a tela de volta e
## percorrer essas linhas -- nao ha estado paralelo para dessincronizar.
##
## Abre em branco (criar) ou com uma fase carregada (editar), conforme
## EditorDeFaseEstado.consumir_caminho().

const CENA_DO_MENU: String = "res://cenas/ui/menu_principal.tscn"
const CENA_DA_SELECAO: String = "res://cenas/ui/selecao_de_fases.tscn"

const _COR_PADRAO_DO_VIGIA: Color = Color(0.40, 0.66, 1.0)
## Mesmo vermelho ja usado no painel de erros: uma so cor de alerta em toda a
## tela, para "isto remove algo" ser reconhecivel de relance.
const _COR_BOTAO_DESTRUTIVO: Color = Color(1, 0.62, 0.6, 1)

const _GERAL: String = "Raiz/Margem/Coluna/Abas/Geral/Margem/Coluna"
const _CACHORROS: String = "Raiz/Margem/Coluna/Abas/Cachorros/Margem/Coluna"
const _PERGUNTAS: String = "Raiz/Margem/Coluna/Abas/Perguntas/Margem/Coluna"

@onready var _abas: TabContainer = $Raiz/Margem/Coluna/Abas
@onready var _campo_titulo: LineEdit = get_node(_GERAL + "/CamposGerais/CampoTitulo")
@onready var _campo_vidas: SpinBox = get_node(_GERAL + "/CamposGerais/CampoVidas")
@onready var _campo_largura: SpinBox = get_node(_GERAL + "/CamposGerais/LinhaMapa/CampoLargura")
@onready var _campo_altura: SpinBox = get_node(_GERAL + "/CamposGerais/LinhaMapa/CampoAltura")
@onready var _campo_semente: SpinBox = get_node(_GERAL + "/CamposGerais/CampoSemente")
@onready var _campo_briefing: TextEdit = get_node(_GERAL + "/CampoBriefing")
## Marcado por padrao numa fase nova: sem ver o comando, quem joga pela
## primeira vez nao sabe o que digitar. Desmarcar e para fase de avaliacao.
@onready var _campo_mostrar_comandos: CheckBox = get_node(_GERAL + "/MostrarComandos")
@onready var _vigias: VBoxContainer = get_node(_CACHORROS + "/RolagemVigias/Vigias")
@onready var _terminais: VBoxContainer = get_node(_PERGUNTAS + "/RolagemTerminais/Terminais")
@onready var _erros: RichTextLabel = $Raiz/Margem/Coluna/Erros
@onready var _titulo_da_tela: Label = $Raiz/Margem/Coluna/Titulo

## Caminho do arquivo sendo editado. Vazio = fase nova (o nome sai do titulo ao
## salvar). Preenchido = salvar grava POR CIMA deste arquivo, sem criar copia.
var _caminho_em_edicao: String = ""
## Id da fase em edicao: preservado para a telemetria ja coletada continuar
## pareando com ela depois de uma edicao.
var _id_fase: String = ""


func _ready() -> void:
	get_node(_CACHORROS + "/AdicionarVigia").pressed.connect(
		func() -> void: _adicionar_vigia())
	get_node(_PERGUNTAS + "/AdicionarTerminal").pressed.connect(
		func() -> void: _adicionar_terminal())
	$Raiz/Margem/Coluna/Acoes/Salvar.pressed.connect(func() -> void: _salvar(false))
	$Raiz/Margem/Coluna/Acoes/SalvarEJogar.pressed.connect(func() -> void: _salvar(true))
	$Raiz/Margem/Coluna/Acoes/Voltar.pressed.connect(_ao_voltar)

	# Titulos em minuscula, no mesmo tom do resto da interface -- os nomes dos
	# nos ficam em PascalCase (convencao do projeto), o texto visivel nao.
	_abas.set_tab_title(0, "geral")
	_abas.set_tab_title(1, "cachorros")
	_abas.set_tab_title(2, "perguntas")
	_abas.tab_changed.connect(_ao_trocar_aba)

	var caminho: String = EditorDeFaseEstado.consumir_caminho()
	if caminho.is_empty():
		_preparar_fase_nova()
	else:
		_carregar(caminho)

	_focar_aba(_abas.current_tab)


## Foco inicial coerente ao entrar em cada aba: o primeiro campo que faz
## sentido preencher, nao "o que sobrou" de onde o mouse estava.
func _ao_trocar_aba(indice: int) -> void:
	_focar_aba(indice)


func _focar_aba(indice: int) -> void:
	match indice:
		0:
			_campo_titulo.grab_focus()
		1:
			if _vigias.get_child_count() > 0:
				(_vigias.get_child(0).get_node("Comando") as LineEdit).grab_focus()
			else:
				get_node(_CACHORROS + "/AdicionarVigia").grab_focus()
		2:
			if _terminais.get_child_count() > 0:
				(_terminais.get_child(0).get_node("Enunciado") as LineEdit).grab_focus()
			else:
				get_node(_PERGUNTAS + "/AdicionarTerminal").grab_focus()


func _preparar_fase_nova() -> void:
	_titulo_da_tela.text = "criar fase"
	_id_fase = Identificador.uuid_v4()
	# Uma fase precisa de pelo menos um terminal para a porta ter o que
	# destrancar; comecar com um vigia e um terminal poupa o professor de
	# descobrir isso pelo erro de validacao.
	_adicionar_vigia()
	_adicionar_terminal()


func _carregar(caminho: String) -> void:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
	if not resultado.ok():
		_mostrar_erros(resultado.erros)
		_preparar_fase_nova()
		return

	var config: FaseConfig = resultado.config
	_caminho_em_edicao = caminho
	_id_fase = config.id_fase
	_titulo_da_tela.text = "editar fase"

	_campo_titulo.text = config.titulo
	_campo_vidas.value = config.vidas_iniciais
	_campo_briefing.text = config.briefing_pedagogico
	_campo_mostrar_comandos.button_pressed = config.mostrar_comandos
	_campo_largura.value = config.mapa.largura() if config.mapa != null else 21
	_campo_altura.value = config.mapa.altura() if config.mapa != null else 15
	# A semente volta para o campo: sem ela, salvar geraria OUTRO labirinto e a
	# fase editada nao seria mais a fase que o professor testou.
	_campo_semente.value = config.semente_do_mapa

	for cachorro: CachorroConfig in config.cachorros:
		_adicionar_vigia(cachorro.cor_efetiva(), cachorro.comando_para_bloquear,
			cachorro.modo_de_bloqueio, cachorro.algoritmo_exigido,
			cachorro.palavra_da_cifra, cachorro.chave_da_cifra)
	for pacote: PacoteConfig in config.pacotes:
		_adicionar_terminal(pacote.enunciado, pacote.opcoes, pacote.resposta_correta,
			pacote.explicacao_correta)


# ---------------------------------------------------------------------------
# Linhas dinamicas
# ---------------------------------------------------------------------------

## Tipos de vigia oferecidos no editor, na ordem do seletor. Cada um e o par
## (modo_de_bloqueio, algoritmo_exigido) que o JSON grava.
const _TIPOS_DE_VIGIA: Array[Dictionary] = [
	{"rotulo": "comando livre", "modo": "COMANDO", "algoritmo": "CESAR"},
	{"rotulo": "cifra de Cesar", "modo": "CIFRA", "algoritmo": "CESAR"},
	{"rotulo": "cifra de Vigenere", "modo": "CIFRA", "algoritmo": "VIGENERE"},
	{"rotulo": "hash SHA-256", "modo": "CIFRA", "algoritmo": "SHA256"},
	{"rotulo": "so persegue", "modo": "NENHUM", "algoritmo": "CESAR"},
]


func _adicionar_vigia(cor: Color = _COR_PADRAO_DO_VIGIA, comando: String = "",
		modo: String = "COMANDO", algoritmo: String = "CESAR",
		palavra: String = "", chave: String = "") -> HBoxContainer:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)

	var seletor := ColorPickerButton.new()
	seletor.custom_minimum_size = Vector2(38, 20)
	seletor.color = cor
	seletor.name = "Cor"
	linha.add_child(seletor)

	# OptionButton e nao um campo de texto: o tipo do vigia decide quais campos
	# fazem sentido, e escolher de uma lista fechada nao deixa o professor
	# escrever um algoritmo que o jogo nao conhece.
	var tipo := OptionButton.new()
	tipo.name = "Tipo"
	tipo.add_theme_font_size_override("font_size", 9)
	for item: Dictionary in _TIPOS_DE_VIGIA:
		tipo.add_item(String(item["rotulo"]))
	tipo.select(_indice_do_tipo(modo, algoritmo))
	linha.add_child(tipo)

	var campo := LineEdit.new()
	campo.name = "Comando"
	campo.text = comando
	campo.placeholder_text = "comando que bloqueia (vazio = so persegue)"
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo.add_theme_font_size_override("font_size", 9)
	linha.add_child(campo)

	var campo_palavra := LineEdit.new()
	campo_palavra.name = "Palavra"
	campo_palavra.text = palavra
	campo_palavra.placeholder_text = "palavra (ex.: senha)"
	campo_palavra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo_palavra.add_theme_font_size_override("font_size", 9)
	linha.add_child(campo_palavra)

	var campo_chave := LineEdit.new()
	campo_chave.name = "Chave"
	campo_chave.text = chave
	campo_chave.custom_minimum_size = Vector2(70, 0)
	campo_chave.add_theme_font_size_override("font_size", 9)
	linha.add_child(campo_chave)

	var remover := Button.new()
	remover.text = "x"
	remover.add_theme_font_size_override("font_size", 9)
	_estilizar_botao_destrutivo(remover)
	remover.pressed.connect(func() -> void:
		_vigias.remove_child(linha)
		linha.queue_free())
	linha.add_child(remover)

	tipo.item_selected.connect(func(_indice: int) -> void: _ajustar_campos_do_vigia(linha))
	_ajustar_campos_do_vigia(linha)
	_vigias.add_child(linha)
	return linha


func _indice_do_tipo(modo: String, algoritmo: String) -> int:
	for i: int in _TIPOS_DE_VIGIA.size():
		var item: Dictionary = _TIPOS_DE_VIGIA[i]
		if item["modo"] == modo and (modo != "CIFRA" or item["algoritmo"] == algoritmo):
			return i
	return 0


## So os campos que o tipo usa ficam visiveis: comando livre pede o comando;
## cifra pede palavra e chave (SHA-256 nao tem chave); "so persegue", nada.
func _ajustar_campos_do_vigia(linha: Node) -> void:
	var item: Dictionary = _TIPOS_DE_VIGIA[(linha.get_node("Tipo") as OptionButton).selected]
	var modo: String = item["modo"]
	var algoritmo: String = item["algoritmo"]
	(linha.get_node("Comando") as Control).visible = modo == "COMANDO"
	(linha.get_node("Palavra") as Control).visible = modo == "CIFRA"
	var chave: LineEdit = linha.get_node("Chave") as LineEdit
	chave.visible = modo == "CIFRA" and algoritmo != "SHA256"
	chave.placeholder_text = "chave 1-25" if algoritmo == "CESAR" else "palavra-chave"


func _adicionar_terminal(enunciado: String = "", opcoes: PackedStringArray = PackedStringArray(),
		correta: String = "", explicacao: String = "") -> VBoxContainer:

	var bloco := VBoxContainer.new()
	bloco.add_theme_constant_override("separation", 3)

	var campo_enunciado := LineEdit.new()
	campo_enunciado.name = "Enunciado"
	campo_enunciado.text = enunciado
	campo_enunciado.placeholder_text = "pergunta (ex.: qual destas e a senha mais dificil de descobrir?)"
	campo_enunciado.add_theme_font_size_override("font_size", 9)
	bloco.add_child(campo_enunciado)

	var lista_de_opcoes := VBoxContainer.new()
	lista_de_opcoes.name = "Opcoes"
	lista_de_opcoes.add_theme_constant_override("separation", 2)
	bloco.add_child(lista_de_opcoes)

	# Um ButtonGroup por terminal: e ele que faz os circulos virarem escolha
	# unica sem nenhuma logica de desmarcar a mao.
	var grupo := ButtonGroup.new()
	bloco.set_meta("grupo", grupo)

	var campo_explicacao := LineEdit.new()
	campo_explicacao.name = "Explicacao"
	campo_explicacao.text = explicacao
	campo_explicacao.placeholder_text = "explicacao mostrada ao acertar (opcional)"
	campo_explicacao.add_theme_font_size_override("font_size", 8)

	var acoes := HBoxContainer.new()
	acoes.add_theme_constant_override("separation", 6)

	var adicionar_opcao := Button.new()
	adicionar_opcao.text = "+ opcao"
	adicionar_opcao.add_theme_font_size_override("font_size", 8)
	adicionar_opcao.pressed.connect(func() -> void:
		_adicionar_opcao(lista_de_opcoes, grupo, "", false))
	acoes.add_child(adicionar_opcao)

	var remover := Button.new()
	remover.text = "remover terminal"
	remover.add_theme_font_size_override("font_size", 8)
	_estilizar_botao_destrutivo(remover)
	remover.pressed.connect(func() -> void:
		_terminais.remove_child(bloco)
		bloco.queue_free())
	acoes.add_child(remover)

	bloco.add_child(campo_explicacao)
	bloco.add_child(acoes)
	_terminais.add_child(bloco)

	if opcoes.is_empty():
		# Duas opcoes de partida: uma pergunta de escolha precisa de pelo menos
		# duas, e a validacao cobraria isso depois de qualquer jeito.
		_adicionar_opcao(lista_de_opcoes, grupo, "", true)
		_adicionar_opcao(lista_de_opcoes, grupo, "", false)
	else:
		for opcao: String in opcoes:
			_adicionar_opcao(lista_de_opcoes, grupo, opcao, opcao == correta)

	return bloco


func _adicionar_opcao(lista: VBoxContainer, grupo: ButtonGroup, texto: String,
		marcada: bool) -> HBoxContainer:

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)

	var marca := CheckBox.new()
	marca.name = "Correta"
	marca.button_group = grupo
	marca.button_pressed = marcada
	linha.add_child(marca)

	var campo := LineEdit.new()
	campo.name = "Texto"
	campo.text = texto
	campo.placeholder_text = "opcao"
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo.add_theme_font_size_override("font_size", 9)
	linha.add_child(campo)

	var remover := Button.new()
	remover.text = "x"
	remover.add_theme_font_size_override("font_size", 8)
	_estilizar_botao_destrutivo(remover)
	remover.pressed.connect(func() -> void:
		lista.remove_child(linha)
		linha.queue_free())
	linha.add_child(remover)

	lista.add_child(linha)
	return linha


func _estilizar_botao_destrutivo(botao: Button) -> void:
	botao.add_theme_color_override("font_color", _COR_BOTAO_DESTRUTIVO)
	botao.add_theme_color_override("font_hover_color", _COR_BOTAO_DESTRUTIVO)
	botao.add_theme_color_override("font_pressed_color", _COR_BOTAO_DESTRUTIVO)


# ---------------------------------------------------------------------------
# Tela -> JSON
# ---------------------------------------------------------------------------

## Le a tela e devolve o dicionario no formato de CarregadorFaseJson. Ler da
## propria arvore de nos (em vez de manter um modelo em paralelo) e o que
## garante que o que o professor VE e o que e salvo.
func montar_dicionario() -> Dictionary:
	var cachorros: Array[Dictionary] = []
	for linha: Node in _vigias.get_children():
		var item: Dictionary = _TIPOS_DE_VIGIA[(linha.get_node("Tipo") as OptionButton).selected]
		var modo: String = item["modo"]
		var comando: String = (linha.get_node("Comando") as LineEdit).text.strip_edges()
		if modo == "COMANDO" and comando.is_empty():
			modo = "NENHUM"  # comando em branco sempre significou "so persegue"
		var vigia: Dictionary = {
			"cor": (linha.get_node("Cor") as ColorPickerButton).color.to_html(false),
			"comando_para_bloquear": comando if modo == "COMANDO" else "",
			"modo_de_bloqueio": modo,
			"algoritmo_exigido": item["algoritmo"],
		}
		if modo == "CIFRA":
			vigia["palavra"] = (linha.get_node("Palavra") as LineEdit).text.strip_edges().to_lower()
			vigia["chave"] = (linha.get_node("Chave") as LineEdit).text.strip_edges().to_lower() \
				if item["algoritmo"] != "SHA256" else ""
		cachorros.append(vigia)

	var terminais: Array[Dictionary] = []
	for bloco: Node in _terminais.get_children():
		var opcoes: Array[String] = []
		var correta := ""
		for linha: Node in bloco.get_node("Opcoes").get_children():
			var texto: String = (linha.get_node("Texto") as LineEdit).text.strip_edges()
			if texto.is_empty():
				continue
			opcoes.append(texto)
			if (linha.get_node("Correta") as CheckBox).button_pressed:
				correta = texto

		terminais.append({
			"enunciado": (bloco.get_node("Enunciado") as LineEdit).text.strip_edges(),
			"opcoes": opcoes,
			"correta": correta,
			"explicacao": (bloco.get_node("Explicacao") as LineEdit).text.strip_edges(),
		})

	return {
		"titulo": _campo_titulo.text.strip_edges(),
		"id_fase": _id_fase,
		"briefing": _campo_briefing.text,
		"mostrar_comandos": _campo_mostrar_comandos.button_pressed,
		"vidas": int(_campo_vidas.value),
		"mapa": {
			"largura": int(_campo_largura.value),
			"altura": int(_campo_altura.value),
			"seed": int(_campo_semente.value),
		},
		"cachorros": cachorros,
		"terminais": terminais,
	}


func _salvar(jogar_depois: bool) -> void:
	var dados: Dictionary = montar_dicionario()

	# Validacao pelo MESMO caminho que a carga usa: se passar aqui, joga.
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(JSON.stringify(dados))
	if not resultado.ok():
		_mostrar_erros(resultado.erros)
		return

	# A semente efetivamente usada volta para o arquivo: pedir "0 = sortear" e
	# gravar 0 faria a proxima abertura sortear outro labirinto.
	dados["mapa"]["seed"] = resultado.config.semente_do_mapa
	_campo_semente.value = resultado.config.semente_do_mapa

	var caminho: String = _caminho_em_edicao
	if caminho.is_empty():
		caminho = CarregadorFaseJson.nome_de_arquivo(String(dados["titulo"]))

	CarregadorFaseJson.garantir_pasta()
	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		_mostrar_erros(PackedStringArray(["nao foi possivel gravar %s (erro %d)"
			% [caminho, FileAccess.get_open_error()]]))
		return

	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.close()
	_caminho_em_edicao = caminho

	if jogar_depois:
		if not Sessao.ativa:
			Sessao.iniciar()
		IniciadorDeFase.jogar(get_tree(), resultado.config)
		return

	_erros.clear()
	_erros.append_text("[color=#1a6b2c]fase salva em %s[/color]" % caminho.get_file())


func _mostrar_erros(erros: PackedStringArray) -> void:
	_erros.clear()
	if erros.is_empty():
		return
	_erros.append_text("[b]a fase ainda nao pode ser salva:[/b]\n- %s" % "\n- ".join(erros))


func _ao_voltar() -> void:
	# Volta para a lista quando veio dela; para o menu quando e fase nova.
	var destino: String = CENA_DA_SELECAO if not _caminho_em_edicao.is_empty() else CENA_DO_MENU
	get_tree().change_scene_to_file(destino)
