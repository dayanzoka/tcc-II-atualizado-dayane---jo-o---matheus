extends Control

## Menu principal.
##
## "Telemetria" abre o Dashboard (cenas/ui/dashboard_telemetria.tscn), que
## responde "o que a coleta diz" -- acertos x erros e tempo por fase. O painel
## de diagnostico tecnico ("a coleta esta funcionando?": modo, fila, sequencia,
## id_sujeito) continua existindo e abre por um botao la dentro; ele nao foi
## removido, so deixou de ser a primeira tela.
##
## O jogo nao tem fase propria embutida -- e ferramenta de autoria (ADR 0012).
## "Escolher fase" e o unico caminho para jogar: lista user://fases/, que
## nunca fica vazia (CarregadorFaseJson.semear_exemplo cria uma de exemplo no
## primeiro boot) e cresce com o que o professor cria ou sobe.

const CENA_DO_DASHBOARD: String = "res://cenas/ui/dashboard_telemetria.tscn"
const CENA_DA_SELECAO: String = "res://cenas/ui/selecao_de_fases.tscn"
const CENA_DO_EDITOR: String = "res://cenas/ui/editor_de_fase.tscn"

## O gatinho do menu e so decoracao (um AnimatedSprite2D cru, sem
## AnimadorDirecional/Jogador por tras) -- por isso o idle-timer dele vive
## aqui, e nao em jogador.gd. Mesma regra pedida para o gato de dentro da
## fase: fica em pe ("parado") ate o mouse ou o teclado ficarem
## tempo_sem_entrada_para_descansar_s sem nenhum evento, ai senta e descansa.
@export_range(1.0, 60.0, 0.5) var tempo_sem_entrada_para_descansar_s: float = 10.0

var _tempo_sem_entrada_s: float = 0.0
var _gato_descansando: bool = false

@onready var _gato: AnimatedSprite2D = $Cartao/Coluna/Mascote/Gato


func _ready() -> void:
	# A fase de exemplo e semeada aqui, e nao no autoload: o jogo so precisa
	# dela quando alguem abre o menu, e escrever em user:// durante um teste
	# headless seria efeito colateral escondido.
	CarregadorFaseJson.semear_exemplo()
	CarregadorFaseJson.atualizar_exemplo()

	$Cartao/Coluna/Botoes/EscolherFase.pressed.connect(_ao_escolher_fase)
	$Cartao/Coluna/Botoes/CriarFase.pressed.connect(_ao_criar_fase)
	$Cartao/Coluna/Botoes/SubirFase.pressed.connect(_ao_subir_fase)
	$DialogoDeImportacao.file_selected.connect(_ao_escolher_arquivo_para_subir)
	$Cartao/Coluna/Botoes/Telemetria.pressed.connect(_ao_abrir_telemetria)
	$Cartao/Coluna/Botoes/Sair.pressed.connect(_ao_sair)
	$Cartao/Coluna/Botoes/EscolherFase.grab_focus()


func _process(delta: float) -> void:
	_tempo_sem_entrada_s += delta
	if not _gato_descansando and _tempo_sem_entrada_s >= tempo_sem_entrada_para_descansar_s:
		_gato_descansando = true
		if _gato.sprite_frames != null and _gato.sprite_frames.has_animation(&"descansar"):
			_gato.play(&"descansar")


## _input() e nao _gui_input(): o menu inteiro conta como "atividade", nao so
## clicar exatamente em cima do gato -- e mouse_filter dos outros controles
## (Fundo, Mascote) ja e IGNORE de proposito, entao nada rouba o evento antes
## dele chegar aqui.
func _input(event: InputEvent) -> void:
	var e_atividade: bool = (event is InputEventMouseMotion or event is InputEventMouseButton
		or event is InputEventKey or event is InputEventScreenTouch
		or event is InputEventScreenDrag or event is InputEventJoypadButton
		or event is InputEventJoypadMotion)
	if not e_atividade:
		return

	_tempo_sem_entrada_s = 0.0
	if _gato_descansando:
		_gato_descansando = false
		_gato.play(&"parado")


## As fases criadas pelo professor: lista, joga, edita, exclui e exporta.
func _ao_escolher_fase() -> void:
	get_tree().change_scene_to_file(CENA_DA_SELECAO)


func _ao_criar_fase() -> void:
	if not ResourceLoader.exists(CENA_DO_EDITOR):
		return
	# Caminho vazio = editor em branco; preenchido = editar fase existente.
	EditorDeFaseEstado.caminho_para_editar = ""
	get_tree().change_scene_to_file(CENA_DO_EDITOR)



func _ao_subir_fase() -> void:
	$DialogoDeImportacao.popup_centered()


## Subir = VALIDAR e so entao copiar para user://fases. Um .json quebrado que
## entrasse na pasta viraria uma linha "(com erro)" na lista da qual o professor
## teria de se livrar depois -- e melhor recusar na porta, dizendo o porque.
func _ao_escolher_arquivo_para_subir(caminho: String) -> void:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_arquivo(caminho)
	if not resultado.ok():
		_avisar("este arquivo nao e uma fase valida:\n\n%s" % resultado.mensagem())
		return

	var destino: String = CarregadorFaseJson.nome_de_arquivo(resultado.config.titulo)
	if FileAccess.file_exists(destino):
		# Nao sobrescrever calado: o professor pode ter uma fase com o mesmo
		# titulo e perder o trabalho dela sem perceber.
		destino = "%s/%s-%s.json" % [CarregadorFaseJson.pasta_das_fases,
			destino.get_file().get_basename(), resultado.config.id_fase.substr(0, 8)]

	var erros: PackedStringArray = CarregadorFaseJson.salvar(resultado.config, destino)
	if not erros.is_empty():
		_avisar("nao foi possivel copiar a fase:\n\n%s" % "\n".join(erros))
		return

	_avisar("fase '%s' adicionada.\nela ja aparece em 'escolher fase'." % resultado.config.titulo)


func _avisar(mensagem: String) -> void:
	$Aviso.dialog_text = mensagem
	$Aviso.popup_centered()


func _ao_abrir_telemetria() -> void:
	get_tree().change_scene_to_file(CENA_DO_DASHBOARD)


func _ao_sair() -> void:
	# Encerrar a sessao e drenar antes de sair e o que transforma "o jogador
	# fechou o jogo" em SESSAO_ENCERRADA em vez de sessao pendurada em ABERTA.
	if Sessao.ativa:
		Sessao.encerrar()
	await Telemetria.descarregar()
	get_tree().quit()


