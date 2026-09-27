extends Control

## Tela de selecao de fases: lista os .json de user://fases e age sobre a
## escolhida.
##
## A lista e a UNICA porta para as fases de autoria -- por isso ela mostra
## titulo e um resumo (quantos vigias, quantos terminais) em vez do nome do
## arquivo: o professor pensa em "Senhas fortes", nao em
## "exemplo-senhas-fortes.json".
##
## Fase com JSON quebrado nao some da lista: aparece marcada com o erro. Sumir
## seria pior -- o professor procuraria um arquivo que ele sabe que existe.

const CENA_DO_MENU: String = "res://cenas/ui/menu_principal.tscn"
const CENA_DO_EDITOR: String = "res://cenas/ui/editor_de_fase.tscn"

@onready var _lista: ItemList = $Raiz/Margem/Coluna/Corpo/Lista
@onready var _detalhe: RichTextLabel = $Raiz/Margem/Coluna/Corpo/Detalhe
@onready var _rodape: Label = $Raiz/Margem/Coluna/Rodape
@onready var _confirmacao: ConfirmationDialog = $ConfirmacaoDeExclusao

var _caminhos: PackedStringArray = PackedStringArray()


func _ready() -> void:
	$Raiz/Margem/Coluna/Acoes/Jogar.pressed.connect(_ao_jogar)
	$Raiz/Margem/Coluna/Acoes/Editar.pressed.connect(_ao_editar)
	$Raiz/Margem/Coluna/Acoes/Exportar.pressed.connect(_ao_exportar)
	$Raiz/Margem/Coluna/Acoes/Excluir.pressed.connect(_ao_pedir_exclusao)
	$DialogoDeExportacao.file_selected.connect(_ao_escolher_destino)
	$Raiz/Margem/Coluna/Acoes/Voltar.pressed.connect(_ao_voltar)
	_lista.item_selected.connect(_ao_selecionar)
	_lista.item_activated.connect(func(_indice: int) -> void: _ao_jogar())
	_confirmacao.confirmed.connect(_ao_confirmar_exclusao)

	_recarregar()


func _recarregar() -> void:
	_lista.clear()
	_caminhos = CarregadorFaseJson.listar()

	if _caminhos.is_empty():
		_detalhe.clear()
		_detalhe.append_text("nenhuma fase ainda.\n\nuse [b]criar fase[/b] no menu para montar a primeira.")
		_definir_acoes_habilitadas(false)
		return

	for caminho: String in _caminhos:
		var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
		if resultado.ok():
			_lista.add_item(resultado.config.titulo)
		else:
			# Marcada, nao escondida: o professor precisa saber qual arquivo
			# quebrou para poder consertar ou excluir.
			_lista.add_item("%s  (com erro)" % caminho.get_file())

	_lista.select(0)
	_ao_selecionar(0)


func _ao_selecionar(indice: int) -> void:
	if indice < 0 or indice >= _caminhos.size():
		return

	var caminho: String = _caminhos[indice]
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)

	_detalhe.clear()
	if not resultado.ok():
		_detalhe.append_text("[b]%s[/b]\n\n[color=#bf2a19]esta fase nao pode ser jogada:[/color]\n%s"
			% [caminho.get_file(), resultado.mensagem()])
		# Excluir continua valendo: e como o professor se livra de um arquivo ruim.
		$Raiz/Margem/Coluna/Acoes/Jogar.disabled = true
		$Raiz/Margem/Coluna/Acoes/Editar.disabled = true
		$Raiz/Margem/Coluna/Acoes/Excluir.disabled = false
		return

	_definir_acoes_habilitadas(true)
	var config: FaseConfig = resultado.config
	var vigias: int = config.cachorros.size()
	var so_perseguem: int = 0
	for cachorro: CachorroConfig in config.cachorros:
		if cachorro.apenas_persegue():
			so_perseguem += 1

	_detalhe.append_text("\n".join(PackedStringArray([
		"[b]%s[/b]" % config.titulo,
		"",
		config.briefing_pedagogico if not config.briefing_pedagogico.is_empty()
			else "[i]sem briefing[/i]",
		"",
		"vidas: %d" % config.vidas_iniciais,
		"vigias: %d (%d so perseguem)" % [vigias, so_perseguem],
		"terminais: %d" % config.pacotes.size(),
		"mapa: %dx%d" % [config.mapa.largura(), config.mapa.altura()],
		"arquivo: %s" % caminho.get_file(),
	])))


func _definir_acoes_habilitadas(habilitadas: bool) -> void:
	$Raiz/Margem/Coluna/Acoes/Jogar.disabled = not habilitadas
	$Raiz/Margem/Coluna/Acoes/Editar.disabled = not habilitadas
	$Raiz/Margem/Coluna/Acoes/Exportar.disabled = not habilitadas
	$Raiz/Margem/Coluna/Acoes/Excluir.disabled = not habilitadas


func _caminho_selecionado() -> String:
	var selecionados: PackedInt32Array = _lista.get_selected_items()
	if selecionados.is_empty():
		return ""
	var indice: int = selecionados[0]
	return _caminhos[indice] if indice < _caminhos.size() else ""


func _ao_jogar() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty():
		return

	if not Sessao.ativa:
		Sessao.iniciar()

	var erros: PackedStringArray = IniciadorDeFase.jogar_arquivo(get_tree(), caminho)
	if not erros.is_empty():
		_rodape.text = "nao foi possivel jogar: %s" % " | ".join(erros)


func _ao_editar() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty():
		return
	# O editor le o caminho daqui; e a unica informacao que precisa atravessar
	# a troca de tela, e um caminho de arquivo nao justifica um autoload.
	if not ResourceLoader.exists(CENA_DO_EDITOR):
		_rodape.text = "o editor visual entra na proxima etapa da reconstrucao."
		return
	EditorDeFaseEstado.caminho_para_editar = caminho
	get_tree().change_scene_to_file(CENA_DO_EDITOR)


## Exportar grava o .json da fase escolhida onde o professor mandar -- e o par
## de "subir": exportar num computador e subir em outro leva a fase inteira,
## porque o arquivo JA e a fase (o mapa viaja como semente, nao desenhado).
func _ao_exportar() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty():
		return
	$DialogoDeExportacao.current_file = caminho.get_file()
	$DialogoDeExportacao.popup_centered()


func _ao_escolher_destino(destino: String) -> void:
	var origem: String = _caminho_selecionado()
	if origem.is_empty():
		return

	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(origem)
	if not resultado.ok():
		_rodape.text = "a fase esta invalida e nao foi exportada."
		return

	var erros: PackedStringArray = CarregadorFaseJson.salvar(resultado.config, destino)
	if not erros.is_empty():
		_rodape.text = "falha ao exportar: %s" % " | ".join(erros)
		return
	_rodape.text = "exportada para %s" % destino


func _ao_pedir_exclusao() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty():
		return
	# Exclusao de arquivo do professor NUNCA e imediata.
	_confirmacao.dialog_text = "excluir a fase '%s'?\nisto apaga o arquivo e nao tem volta." \
		% caminho.get_file()
	_confirmacao.popup_centered()


func _ao_confirmar_exclusao() -> void:
	var caminho: String = _caminho_selecionado()
	if caminho.is_empty():
		return

	var erro: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	if erro != OK:
		_rodape.text = "nao foi possivel excluir %s (erro %d)" % [caminho.get_file(), erro]
		return

	_rodape.text = "fase '%s' excluida." % caminho.get_file()
	_recarregar()


func _ao_voltar() -> void:
	get_tree().change_scene_to_file(CENA_DO_MENU)
