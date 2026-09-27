class_name FaseBase
extends Node2D

## CENA PAI de todas as fases. Nao e jogavel sozinha.
##
## Aqui mora toda a logica de fase; as fases concretas (cenas/fases/fase_0N.tscn)
## sao cenas herdadas que trazem apenas dois dados: o FaseConfig atribuido no
## Inspector e o labirinto desenhado no TileMapLayer. O objetivo declarado na
## monografia -- "adicionar fases com baixo esforco de codificacao, atraves do
## uso de matrizes de dados" -- se cumpre ou se perde neste arquivo.
##
## Regra de ouro: se a mesma linha for necessaria em fase_01 e fase_02, ela
## pertence a este arquivo. Se uma fase precisar de script proprio, a
## generalizacao falhou e o conserto e aqui, nao la.

signal fase_concluida(numero: int)
signal fase_abandonada(numero: int)

const CENA_DO_MENU: String = "res://cenas/ui/menu_principal.tscn"

## O unico ponto de configuracao de uma fase. Sem ele a cena nao roda -- e isso
## e proposital: fase_base.tscn aberta direto no editor tem que falhar com
## mensagem clara, nao rodar meio funcionando.
@export var configuracao: FaseConfig

@onready var labirinto: TileMapLayer = $Labirinto
@onready var jogador: Jogador = $Jogador
## Cachorro que ja vem na cena pai. Continua sendo o cachorro numero 1 da fase
## (as fases nao precisam instanciar o primeiro); os demais nascem de
## FaseConfig.cachorros em _configurar_cachorros(). Use `cachorros` para
## qualquer logica que valha para todos.
@onready var cachorro: Cachorro = $Cachorro
@onready var camera: Camera2D = $CameraJogador
@onready var marcadores: Node2D = $Marcadores
@onready var ponto_de_entrada: Marker2D = $Marcadores/PontoDeEntrada
@onready var ponto_de_saida: Porta = $Marcadores/PontoDeSaida
@onready var pacotes_no: Node2D = $Marcadores/Pacotes
@onready var regioes_no: Node2D = $Marcadores/Regioes
@onready var hud: Hud = $Hud
@onready var terminal: Terminal = $Terminal
@onready var painel_cifra: PainelCifra = $PainelCifra
@onready var caixa_puzzle: CaixaPuzzle = $CaixaPuzzle
@onready var tela_captura: TelaCaptura = $TelaCaptura
@onready var painel_pause: PainelDePause = $PainelDePause
@onready var aviso: CanvasLayer = $AvisoDeConfiguracao
@onready var _rotulo_do_aviso: Label = $AvisoDeConfiguracao/Fundo/Texto

var _configurada: bool = false
var _encerrada: bool = false
var _capturas: int = 0
var _camera_segue_jogador: bool = true

## IA de perseguicao (scripts/ia/navegacao.gd, wrapper de AStarGrid2D). Uma
## instancia por fase porque a grade depende do labirinto desta cena.
var _navegacao: Navegacao = Navegacao.new()
var _temporizador_replanejamento: Timer = null
## Verdadeiro quando ALGUM cachorro tem linha de visao. A deteccao por cachorro
## (que e a que vai para a telemetria) mora em _visao_por_cachorro.
var _cachorro_com_linha_de_visao: bool = false
var _depuracao_astar_visivel: bool = false

## Todos os cachorros da fase, incluindo o da cena pai na posicao 0.
var cachorros: Array[Cachorro] = []
var _config_por_cachorro: Dictionary = {}   # Cachorro -> CachorroConfig
var _visao_por_cachorro: Dictionary = {}    # Cachorro -> bool
var _ancora_por_cachorro: Dictionary = {}   # Cachorro -> int (indice da patrulha)
var _nascimento_por_cachorro: Dictionary = {}  # Cachorro -> Vector2 (volta aqui apos captura)

## Tela de captura aberta: o mundo esta pausado e nenhum outro contato conta.
var _em_captura: bool = false
## Ticks (ms) ate quando o jogador nao pode ser capturado, depois de voltar.
var _invulneravel_ate_ms: int = 0
## A invulnerabilidade acabou com um cachorro ja encostado? body_entered nao
## dispara de novo nesse caso, entao o contato e conferido uma vez a mao.
var _conferir_contato_pendente: bool = false

const _CENA_DO_CACHORRO: String = "res://cenas/base/cachorro.tscn"
const _CENA_DO_PACOTE: String = "res://cenas/base/pacote.tscn"

## Pacotes da fase e progresso da coleta. A porta so abre com todos coletados.
var pacotes: Array[Pacote] = []
var _pacotes_coletados: int = 0
var _pacote_em_puzzle: Pacote = null
var _tentativas_por_pacote: Dictionary = {}   # identificador -> int

## Diretor de IA (Marco 2, scripts/ia/diretor.gd). Null quando a fase nao tem
## nenhuma regiao em Marcadores/Regioes (o caso comum de uma fase de autoria,
## que nunca declara regiao) -- sem Diretor, o cachorro continua perseguindo
## a posicao real sempre, exatamente o comportamento original do Marco 1
## (docs/decisoes/0007, decisao 1).
var _diretor: Diretor = null
var _temporizador_diretor: Timer = null
var _regiao_atual_do_jogador: Area2D = null
var _indice_varredura: int = 0

## Progresso do terminal. Marco 1 nao tem "escolher desafio": os desafios de
## FaseConfig.desafios sao resolvidos em ordem -- e a decisao mais simples que
## atende Cesar e Vigenere sem mudar (docs/decisoes/0007-marco1-cachorro-e-desafios.md).
var _indice_desafio: int = 0
var _numero_tentativa_do_desafio: int = 1
## Identificadores ja resolvidos ao menos uma vez -- o que separa "resolveu" de
## "reaplicou a cifra para atravessar" na hora de pontuar.
var _desafios_resolvidos: Dictionary = {}

## Instrumentacao de desempenho (Marco 3, Eixo 7): acumula desde a ultima
## AMOSTRA_DESEMPENHO para reportar a MEDIA do tempo de replanejamento, nao
## so a ultima amostra isolada -- um pico unico nao prova nada sobre
## orcamento de quadro, uma media ao longo de 30s prova.
const _INTERVALO_AMOSTRA_DESEMPENHO_S: float = 30.0
var _temporizador_desempenho: Timer = null
var _soma_replanejamento_us: int = 0
var _contagem_replanejamento: int = 0


func _ready() -> void:
	aviso.visible = false

	var problema: String = _diagnosticar()
	if problema != "":
		_falhar(problema)
		return

	_configurada = true
	_conectar_sinais()

	# O mapa e a PRIMEIRA coisa: ele repinta o labirinto e reposiciona entrada e
	# saida, e todo o resto (navegacao, cachorros, pacotes, camera) depende
	# desse desenho ja estar no lugar.
	_aplicar_mapa()

	jogador.reposicionar(ponto_de_entrada.global_position)
	jogador.velocidade = maxf(jogador.velocidade, 1.0)
	_configurar_cachorros()
	_configurar_pacotes()

	_navegacao.configurar(labirinto)
	_configurar_camera()
	_configurar_temporizador_replanejamento()
	_configurar_diretor()
	_configurar_temporizador_desempenho()
	_replanejar_caminho_do_cachorro()

	# A identidade da fase entra na sessao ANTES do primeiro evento: FASE_INICIADA
	# ja precisa sair com id_fase preenchido.
	Sessao.entrar_na_fase(configuracao.numero, configuracao.vidas_iniciais,
		configuracao.garantir_id_fase(), configuracao.titulo)
	hud.definir_titulo("fase %d -- %s" % [configuracao.numero, configuracao.titulo])
	if configuracao.mostrar_comandos:
		hud.mostrar_comandos(_legenda_de_comandos())

	Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {
		"algoritmo": configuracao.algoritmo,
		"desafios": configuracao.desafios.size(),
		"vidas_iniciais": configuracao.vidas_iniciais,
	}, configuracao.numero)

	if configuracao.briefing_pedagogico != "":
		terminal.escrever(configuracao.briefing_pedagogico)
	var desafio_inicial: DesafioConfig = _desafio_atual()
	if desafio_inicial != null:
		terminal.escrever("desafio: %s" % desafio_inicial.enunciado)


func _physics_process(_delta: float) -> void:
	if not _configurada:
		return
	# A camera segue o jogador por posicao, e nao por parentesco, para poder
	# aplicar limites (limit_left/right) vindos do tamanho do labirinto sem
	# mexer na cena do jogador. Quando o labirinto inteiro cabe na tela,
	# _configurar_camera desliga o seguimento e fixa a camera no centro do mapa.
	if _camera_segue_jogador:
		camera.global_position = jogador.global_position
	_atualizar_deteccao_do_cachorro()
	_conferir_contato_apos_invulnerabilidade()


func _draw() -> void:
	# Depuracao visual obrigatoria (secao 6 do CLAUDE.md, apontamento 7): F3
	# mostra o caminho que o AStarGrid2D calculou por ultimo. Os "nos
	# expandidos" do algoritmo NAO aparecem aqui de proposito -- AStarGrid2D
	# nao expoe o conjunto fechado pela API publica, e astar_referencia.gd (que
	# expoe) e explicitamente vetada para uso em runtime pela secao 2 do
	# CLAUDE.md. Registrado como pendencia no relatorio de fim de marco.
	if not _depuracao_astar_visivel:
		return

	# Cada caminho sai na cor do cachorro que o segue: com varios cachorros em
	# cena, um unico vermelho para todos transformaria a demo da IA num
	# emaranhado ilegivel justamente na hora de explica-la para a banca.
	for alvo: Cachorro in cachorros:
		var caminho: PackedVector2Array = alvo.caminho_atual()
		if caminho.size() < 2:
			continue

		var pontos_locais := PackedVector2Array()
		for ponto: Vector2 in caminho:
			pontos_locais.append(to_local(ponto))

		var cor_do_caminho: Color = alvo.cor()
		cor_do_caminho.a = 0.9
		draw_polyline(pontos_locais, cor_do_caminho, 1.5)
		for ponto_local: Vector2 in pontos_locais:
			draw_circle(ponto_local, 2.0, cor_do_caminho)


func _unhandled_input(evento: InputEvent) -> void:
	if not _configurada or _encerrada:
		return

	if evento.is_action_pressed("alternar_depuracao"):
		_depuracao_astar_visivel = not _depuracao_astar_visivel
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("mostrar_demonstracao"):
		_alternar_painel_de_demonstracao()
		get_viewport().set_input_as_handled()
		return

	# Abrir o terminal pausa a arvore, e a partir dai este _unhandled_input nao
	# roda mais (FaseBase e PAUSABLE): quem trata as teclas de FECHAR e o
	# proprio terminal, que tem process_mode ALWAYS. Por isso aqui so existe o
	# caminho de abrir.
	if evento.is_action_pressed("abrir_terminal"):
		terminal.abrir()
		get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("pausar"):
		# So chega aqui quando nada mais pausou a arvore (terminal, puzzle):
		# enquanto QUALQUER um deles esta aberto, get_tree().paused ja e true
		# e FaseBase (PAUSABLE, o padrao) simplesmente nao recebe
		# _unhandled_input -- so nos ALWAYS recebem, e sao eles que tratam a
		# propria tecla de fechar (ver terminal.gd e painel_pause.gd).
		#
		# Em modo de treino (agente de RL) a tecla nao faz nada: o menu de
		# pause e feito para o jogador humano ler e decidir, e um episodio de
		# treino nao deve travar esperando uma decisao de UI.
		if not ConfigJogo.modo_treino:
			_abrir_pause()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Ciclo da fase
# ---------------------------------------------------------------------------

func concluir() -> void:
	if _encerrada or not _configurada:
		return
	_encerrada = true
	_garantir_jogo_despausado()
	Telemetria.registrar_evento(CatalogoEventos.FASE_CONCLUIDA, {
		"capturas": _capturas,
		"pontuacao": Sessao.pontuacao,
		"vidas_restantes": Sessao.vidas,
	}, configuracao.numero)
	Sessao.sair_da_fase()
	fase_concluida.emit(configuracao.numero)
	_voltar_ao_menu()


func abandonar() -> void:
	if _encerrada or not _configurada:
		return
	_encerrada = true
	_registrar_abandono()
	fase_abandonada.emit(configuracao.numero)
	_voltar_ao_menu()


## Reinicia a fase corrente do zero: uma FaseBase nova com a MESMA
## configuracao, o que roda _ready() de novo com uma partida nova (vidas,
## pontuacao de fase, progresso de desafio).
##
## Nao usa reload_current_scene(): ele recarrega fase_base.tscn do disco, e uma
## fase de autoria nao tem .tscn propria -- a configuracao existe so em
## memoria. A cena recarregada nascia sem FaseConfig e caia na tela de
## "configuracao invalida". IniciadorDeFase e o mesmo caminho que o menu usa.
## Conta como abandono da tentativa em curso -- o jogador esta descartando o
## que tinha feito nesta partida de proposito, e e essa distincao que separa
## isto do reinicio silencioso de _ao_esgotar_vidas() (o mesmo intento, sem
## descartar a tentativa: as vidas voltam mas o progresso do desafio fica).
func reiniciar() -> void:
	if _encerrada or not _configurada:
		return
	_encerrada = true
	_registrar_abandono()
	fase_abandonada.emit(configuracao.numero)
	IniciadorDeFase.jogar(get_tree(), configuracao)


## Telemetria e saida da sessao compartilhadas por abandonar() e reiniciar():
## as duas fecham a tentativa corrente como ABANDONO, so o destino depois
## diverge (menu vs. a mesma fase de novo).
func _registrar_abandono() -> void:
	_garantir_jogo_despausado()

	# Desafio deixado pra tras sem solucao: registra ABANDONO nessa tentativa
	# em vez de simplesmente nao gerar nenhuma linha. E o unico gatilho de
	# gameplay deste marco para o resultado ABANDONO -- documentado em
	# docs/decisoes/0007-marco1-cachorro-e-desafios.md junto com a pendencia de
	# TIMEOUT (sem mecanica de prazo por desafio especificada ate aqui).
	var desafio_atual: DesafioConfig = _desafio_atual()
	if desafio_atual != null:
		Telemetria.registrar_tentativa(
			configuracao.numero, desafio_atual.identificador, "", [],
			CatalogoResultados.ABANDONO, "", 0, _numero_tentativa_do_desafio)

	Telemetria.registrar_evento(CatalogoEventos.FASE_ABANDONADA, {
		"capturas": _capturas,
		"pontuacao": Sessao.pontuacao,
	}, configuracao.numero)
	Sessao.sair_da_fase()


func _conectar_sinais() -> void:
	jogador.protecao_alterada.connect(hud.mostrar_protecao)
	# O contato de cada cachorro e conectado em _preparar_cachorro, com o
	# proprio cachorro em bind() -- a fase precisa saber QUAL encostou para
	# decidir se a cifra ativa protege contra aquela cor.
	terminal.comando_submetido.connect(_ao_submeter_comando)
	terminal.aberto.connect(_ao_abrir_terminal)
	terminal.fechado.connect(_ao_fechar_terminal)
	tela_captura.encerrada.connect(_ao_terminar_captura)
	caixa_puzzle.respondido.connect(_ao_responder_puzzle)
	caixa_puzzle.cancelada.connect(_fechar_puzzle)
	ponto_de_saida.body_entered.connect(_ao_chegar_na_saida)
	Sessao.vidas_esgotadas.connect(_ao_esgotar_vidas)
	painel_pause.continuar_pressionado.connect(_ao_fechar_pause)
	painel_pause.reiniciar_pressionado.connect(reiniciar)
	painel_pause.voltar_ao_menu_pressionado.connect(abandonar)


## O terminal pausa o jogo, como a caixa de puzzle.
##
## Digitar 'cifrar pacote chave=3' com um cachorro colado nas costas nao mede
## se o jogador aprendeu a cifra: mede a velocidade de digitacao dele sob
## panico. Pausando, o terminal vira o que deveria ser -- o momento de PENSAR
## qual ferramenta a cor pede e qual e a chave.
##
## Consequencias, todas desejadas:
## - a duracao da protecao (FaseConfig.duracao_cifra_s) corre em
##   Jogador._physics_process, que nao roda pausado, entao a pausa NAO consome
##   tempo de cifra: o jogador nao e punido por ler o enunciado com calma;
## - tempo_resposta_ms continua medindo o relogio de parede (Relogio.marca_ms),
##   ou seja, o tempo que o jogador levou PENSANDO -- que e exatamente a
##   metrica do Eixo 1, e agora sem o ruido da fuga simultanea;
## - o temporizador de descarga da Telemetria tambem para; a fila acumula em
##   memoria e drena ao despausar (mesmo efeito ja aceito para o puzzle).
func _ao_abrir_terminal() -> void:
	jogador.definir_entrada_habilitada(false)
	get_tree().paused = true


func _ao_fechar_terminal() -> void:
	# A caixa de puzzle tambem pausa: se ela estiver aberta, quem manda
	# despausar e ela, nao o terminal.
	if _pacote_em_puzzle == null:
		get_tree().paused = false
	if not _encerrada:
		jogador.definir_entrada_habilitada(true)


## A porta so deixa passar com todos os pacotes na mao. Chegar nela sem eles nao
## e falha nem punicao: e a propria porta dizendo o que falta.
func _ao_chegar_na_saida(corpo: Node2D) -> void:
	if not (corpo is Jogador):
		return
	if _porta_trancada():
		terminal.escrever("a porta esta trancada: faltam %d pacote(s) de dados."
			% (pacotes.size() - _pacotes_coletados))
		return
	concluir()


func _porta_trancada() -> bool:
	return _pacotes_coletados < pacotes.size()


## Contato so intercepta se a cifra ativa NAO for a que engana este cachorro.
## Em texto claro qualquer cachorro intercepta; com a cifra certa ele passa por
## cima sem entender nada -- que e a licao da fase. Com a cifra ERRADA (cifrou
## em Cesar e quem veio le Vigenere) tambem intercepta, e essa e a licao nova:
## proteger nao e um interruptor, e escolher o algoritmo certo.
func _ao_encostar_no_jogador(_corpo: Node2D, cachorro_que_encostou: Cachorro) -> void:
	# Uma captura por vez: cercado por dois cachorros, o jogador perdia duas
	# vidas no mesmo instante (e outra ao voltar, se um deles estava na entrada).
	if _encerrada or _em_captura or jogador_invulneravel() \
			or _protegido_contra(cachorro_que_encostou):
		return

	_capturas += 1
	Telemetria.registrar_evento(CatalogoEventos.JOGADOR_CAPTURADO, {
		"protecao_ativa": jogador.protecao_ativa,
		"algoritmo_protegido": jogador.algoritmo_protegido,
		"cachorro": cachorro_que_encostou.identificador,
		"algoritmo_exigido": cachorro_que_encostou.algoritmo_exigido,
		"captura_numero": _capturas,
	}, configuracao.numero)

	if _diretor != null:
		_diretor.pista_captura(_regiao_atual_do_jogador)

	Sessao.perder_vida()
	Sessao.somar_pontos(-configuracao.penalidade_captura)
	jogador.definir_entrada_habilitada(false)
	for outro: Cachorro in cachorros:
		outro.parar()
	# Congela o mundo enquanto a tela explica: so parar() nao bastava, o
	# temporizador de replanejamento dava rota nova e os cachorros seguiam
	# ate o jogador parado. A tela de captura roda em PROCESS_MODE_ALWAYS.
	_em_captura = true
	get_tree().paused = true
	tela_captura.mostrar("pacote interceptado", _explicacao_da_captura(cachorro_que_encostou))


## A cifra ativa engana este cachorro?
##
## Em modo de treino (ConfigJogo.modo_treino, usado pelo agente de aprendizado
## por reforco) qualquer cifra ativa protege: a mecanica de cores existe para o
## jogador humano ler a cor na tela, e um agente treinado no contrato antigo
## nao deve ser quebrado por ela.
func _protegido_contra(cachorro_alvo: Cachorro) -> bool:
	if not jogador.protecao_ativa:
		return false
	if ConfigJogo.modo_treino:
		return true

	# Dois modos convivem, e o cachorro diz qual e o dele:
	#   - fase de autoria: ele traz um comando em texto livre, e so digitar
	#     AQUELE comando o bloqueia (comparacao exata);
	#   - fases 1 a 3: nao ha comando, e vale a cifra exigida.
	# Vigia que so persegue: nada o bloqueia, a defesa e fugir. Sem este
	# retorno ele caia na regra da cifra e qualquer "cifrar" o desligava.
	if _apenas_persegue(cachorro_alvo):
		return false

	if cachorro_alvo.bloqueia_por_comando():
		return jogador.comando_protegido == cachorro_alvo.comando_para_bloquear

	return jogador.algoritmo_protegido == cachorro_alvo.algoritmo_exigido


func _apenas_persegue(cachorro_alvo: Cachorro) -> bool:
	var config_do_cachorro: CachorroConfig = _config_por_cachorro.get(cachorro_alvo) as CachorroConfig
	return config_do_cachorro != null and config_do_cachorro.apenas_persegue()


## A tela de captura e o momento em que o jogador mais quer saber o porque --
## por isso a explicacao distingue os tres casos em vez de repetir "voce foi
## pego" (secao 7 do CLAUDE.md: enquadramento pedagogico, nao punitivo).
func _explicacao_da_captura(cachorro_alvo: Cachorro) -> String:
	if _apenas_persegue(cachorro_alvo):
		return "este vigia nao tem comando que o pare: a unica defesa e fugir dele."

	if cachorro_alvo.bloqueia_por_comando():
		if configuracao.mostrar_comandos:
			return "este vigia so para com o comando '%s' no terminal (tecla T)." \
				% cachorro_alvo.comando_para_bloquear
		return "este vigia so para com o comando certo no terminal (tecla T). descubra qual."

	var exigido: String = LegendaCores.nome(cachorro_alvo.algoritmo_exigido)

	if not jogador.protecao_ativa:
		var texto: String = ("o pacote viajava em texto claro. este interceptador le %s: "
			+ "use o terminal para cifrar antes de atravessar.") % exigido
		var config_do_cachorro: CachorroConfig = _config_por_cachorro.get(cachorro_alvo) as CachorroConfig
		if configuracao.mostrar_comandos and config_do_cachorro != null \
				and not config_do_cachorro.comando_da_cifra().is_empty():
			texto += " comando: %s" % config_do_cachorro.comando_da_cifra()
		return texto

	return ("a cifra ativa era %s, mas este interceptador so e enganado por %s. "
		+ "cifrar nao basta: tem que ser a cifra certa para o interceptador certo.") % [
			LegendaCores.nome(jogador.algoritmo_protegido), exigido]


## Volta ao inicio como no Pac-Man: o jogador na entrada, cada cachorro no
## ponto onde nasceu, e alguns segundos de invulnerabilidade. Sem devolver os
## cachorros, quem tinha acabado de pegar o jogador perto da entrada estava
## em cima dele de novo.
func _ao_terminar_captura() -> void:
	jogador.reposicionar(ponto_de_entrada.global_position)
	jogador.cancelar_protecao()
	jogador.definir_entrada_habilitada(true)

	for alvo: Cachorro in cachorros:
		alvo.parar()
		if _nascimento_por_cachorro.has(alvo):
			alvo.global_position = _nascimento_por_cachorro[alvo]
		_ancora_por_cachorro[alvo] = 0
		_visao_por_cachorro[alvo] = false

	_em_captura = false
	get_tree().paused = false
	var duracao_s: float = configuracao.invulnerabilidade_apos_captura_s
	_invulneravel_ate_ms = Time.get_ticks_msec() + int(duracao_s * 1000.0)
	_conferir_contato_pendente = duracao_s > 0.0
	jogador.piscar(duracao_s)
	_replanejar_caminho_do_cachorro()


func jogador_invulneravel() -> bool:
	return Time.get_ticks_msec() < _invulneravel_ate_ms


func _conferir_contato_apos_invulnerabilidade() -> void:
	if not _conferir_contato_pendente or jogador_invulneravel() or _em_captura:
		return
	_conferir_contato_pendente = false
	for alvo: Cachorro in cachorros:
		if alvo.esta_encostando(jogador):
			_ao_encostar_no_jogador(jogador, alvo)
			return


func _ao_esgotar_vidas() -> void:
	if _encerrada:
		return
	# Vidas zeradas reinicia a fase; nao expulsa do jogo (secao 7 do CLAUDE.md).
	Sessao.repor_vidas(configuracao.vidas_iniciais)
	terminal.escrever("vidas esgotadas. a fase recomeca -- o pacote volta ao inicio.")


# ---------------------------------------------------------------------------
# Terminal: pipeline lexico -> sintatico -> semantico
# ---------------------------------------------------------------------------

## ERRO_LEXICO e ERRO_SINTATICO sao veredito final de AnalisadorComando; so
## quando os dois passam e que ResolvedorComando entra para decidir SUCESSO vs
## ERRO_SEMANTICO contra o FaseConfig e o desafio corrente.
func _ao_submeter_comando(texto: String, tempo_resposta_ms: int) -> void:
	# Comando livre de fase de autoria vem ANTES do analisador, de proposito: o
	# professor escreve o comando que quiser ("desligue o roteador", "bloquear
	# porta 22"), e isso nao precisa caber na gramatica do terminal do TCC --
	# que continua valendo, intacta, para tudo o mais. Comparacao exata, como o
	# formato promete.
	if _tentar_comando_de_bloqueio(texto, tempo_resposta_ms):
		return

	_analisar_comando(texto, tempo_resposta_ms)


## Devolve true quando o texto bloqueou algum cachorro -- e ai o comando ja foi
## tratado e registrado, e o pipeline lexico nao roda.
func _tentar_comando_de_bloqueio(texto: String, tempo_resposta_ms: int) -> bool:
	var limpo: String = texto.strip_edges()
	if limpo.is_empty():
		return false

	for alvo: Cachorro in cachorros:
		if not alvo.bloqueia_por_comando() or alvo.comando_para_bloquear != limpo:
			continue

		jogador.ativar_protecao(configuracao.duracao_cifra_s, "", limpo)
		terminal.escrever("comando aceito: '%s' bloqueia este interceptador por %.0fs."
			% [limpo, configuracao.duracao_cifra_s])

		# Entra na telemetria como qualquer outra tentativa: e uma resposta do
		# jogador, com tempo de resposta e resultado, e a analise precisa dela.
		Telemetria.registrar_tentativa(
			configuracao.numero, "comando-%s" % alvo.identificador, limpo, [],
			CatalogoResultados.SUCESSO, "", tempo_resposta_ms, 1)
		return true

	return false


func _analisar_comando(texto: String, tempo_resposta_ms: int) -> void:
	var resultado: ResultadoComando = AnalisadorComando.analisar(texto)

	if resultado.resultado == CatalogoResultados.ERRO_LEXICO:
		terminal.escrever("erro lexico: caractere nao reconhecido no comando.")
		Telemetria.registrar_evento(CatalogoEventos.ERRO_LEXICO, {}, configuracao.numero)
		_registrar_tentativa(resultado, resultado.resultado, resultado.codigo_erro, tempo_resposta_ms)
		if _diretor != null:
			_diretor.pista_comando_errado(_regiao_atual_do_jogador)
		return

	if resultado.resultado == CatalogoResultados.ERRO_SINTATICO:
		terminal.escrever("erro sintatico: comando mal formado. digite 'status' para ver o desafio atual.")
		Telemetria.registrar_evento(CatalogoEventos.ERRO_SINTATICO, {}, configuracao.numero)
		_registrar_tentativa(resultado, resultado.resultado, resultado.codigo_erro, tempo_resposta_ms)
		if _diretor != null:
			_diretor.pista_comando_errado(_regiao_atual_do_jogador)
		return

	_focar_desafio_do_comando(resultado.ast)
	var desafio_atual: DesafioConfig = _desafio_atual()
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		configuracao, desafio_atual, _numero_tentativa_do_desafio, resultado)

	terminal.escrever(veredicto.texto_para_terminal)
	_registrar_tentativa(resultado, veredicto.resultado, veredicto.codigo_erro, tempo_resposta_ms)

	if veredicto.resultado != CatalogoResultados.SUCESSO and _diretor != null:
		_diretor.pista_comando_errado(_regiao_atual_do_jogador)

	# Desafio ja resolvido antes nao pontua de novo: com o ciclo de desafios
	# (ver _avancar_desafio) o jogador pode reaplicar a mesma cifra quantas
	# vezes precisar para atravessar o labirinto, e pontuar a cada repeticao
	# transformaria o placar num contador de digitacao, nao de aprendizado.
	var ja_resolvido: bool = desafio_atual != null \
		and _desafios_resolvidos.has(desafio_atual.identificador)
	if veredicto.delta_pontos != 0 and not (ja_resolvido and veredicto.resolveu_desafio):
		Sessao.somar_pontos(veredicto.delta_pontos)

	if veredicto.dica_solicitada and desafio_atual != null:
		Telemetria.registrar_evento(CatalogoEventos.DICA_SOLICITADA,
			{"desafio": desafio_atual.identificador}, configuracao.numero)

	if veredicto.resolveu_desafio:
		_explicar_no_terminal(desafio_atual, veredicto.algoritmo_protecao)
		jogador.ativar_protecao(veredicto.duracao_protecao_s, veredicto.algoritmo_protecao)
		_avancar_desafio()
	elif _e_tentativa_do_desafio_corrente(desafio_atual, resultado.ast.verbo):
		# So conta como nova tentativa do MESMO desafio quando o verbo bate com
		# o que o desafio espera -- "status" e "dica" nao consomem tentativa.
		_numero_tentativa_do_desafio += 1


## Mostra no terminal O QUE ACABOU DE ACONTECER com o pacote -- letra a letra.
##
## Antes, acertar imprimia so "pacote protegido": o jogador via a recompensa e
## nao via a transformacao, entao a cifra continuava sendo um botao magico. Aqui
## ele le o texto claro, a chave alinhada e o resultado, e a frase que fecha a
## licao: o cachorro passa a ver OUTRA palavra.
##
## O alinhamento vem de DemonstracaoCifra.montar(), a MESMA funcao que alimenta
## o painel de demonstracao -- nao ha uma segunda forma de explicar a cifra
## neste projeto. E de proposito NAO emite CIFRA_DEMONSTRADA: aquele evento mede
## o jogador ESCOLHER ver a explicacao (Eixo 2); emiti-lo a cada acerto
## transformaria o indicador num contador de acertos.
func _explicar_no_terminal(desafio: DesafioConfig, algoritmo: String) -> void:
	if desafio == null:
		return

	if algoritmo == "SHA256":
		# Hash nao tem "antes e depois" para alinhar: a licao dele e outra, e a
		# confusao hash x cifra e o erro conceitual mais comum do tema.
		terminal.escrever("o resumo confere: o conteudo nao foi adulterado no caminho.")
		terminal.escrever("repare que voce NAO escondeu nada -- o resumo e de mao unica, "
			+ "nao existe desfazer. ele serve para provar integridade, nao para dar sigilo.")
		return

	var cifra: Cifra = FabricaCifra.para_algoritmo(algoritmo)
	if cifra == null or desafio.texto_claro.is_empty():
		return

	var linhas: Array[DemonstracaoCifra.Linha] = DemonstracaoCifra.montar(
		desafio.texto_claro, desafio.chave_esperada, cifra)

	var claro := ""
	var chaves := ""
	var cifrado := ""
	for linha: DemonstracaoCifra.Linha in linhas:
		# Uma coluna de largura fixa por letra: alinhado em fonte monoespacada,
		# que e a do terminal.
		claro += "%-3s" % linha.claro
		chaves += "%-3s" % (linha.chave if linha.chave != "" else "-")
		cifrado += "%-3s" % linha.cifrado

	terminal.escrever("--- o que aconteceu com o pacote ---")
	terminal.escrever("claro   : %s" % claro)
	terminal.escrever("chave   : %s" % chaves)
	terminal.escrever("cifrado : %s" % cifrado)
	terminal.escrever("o cachorro agora ve '%s', e nao '%s' -- e por isso que ele passa direto."
		% [cifra.cifrar(desafio.texto_claro, desafio.chave_esperada), desafio.texto_claro])


func _registrar_tentativa(
		resultado: ResultadoComando, resultado_final: String, codigo_erro: String, tempo_resposta_ms: int) -> void:
	var desafio_atual: DesafioConfig = _desafio_atual()
	var identificador_desafio: String = desafio_atual.identificador if desafio_atual != null \
		else "sem-desafio-ativo"
	Telemetria.registrar_tentativa(
		configuracao.numero,
		identificador_desafio,
		resultado.texto_normalizado,
		resultado.tokens_para_telemetria(),
		resultado_final,
		codigo_erro,
		tempo_resposta_ms,
		_numero_tentativa_do_desafio)


## Com mais de um vigia de cifra, cada um tem o seu desafio, e o jogador digita
## o comando do vigia que esta na frente dele -- nao o "proximo da fila". Se o
## comando corresponde a OUTRO desafio da fase (mesmo verbo, mesma palavra),
## ele passa a ser o corrente antes da validacao semantica. Comando que nao
## corresponde a nenhum continua sendo julgado contra o corrente, e o erro
## semantico sai igual ao de antes.
func _focar_desafio_do_comando(ast: NoAst) -> void:
	if ast == null or configuracao.desafios.size() < 2:
		return
	var soltos: Array[String] = ast.argumentos_soltos()
	if soltos.is_empty():
		return
	for i: int in configuracao.desafios.size():
		var desafio: DesafioConfig = configuracao.desafios[i]
		if desafio.verbo_esperado == ast.verbo and desafio.texto_claro == soltos[0]:
			if i != _indice_desafio:
				_indice_desafio = i
				_numero_tentativa_do_desafio = 1
			return


func _e_tentativa_do_desafio_corrente(desafio_atual: DesafioConfig, verbo: String) -> bool:
	return desafio_atual != null and verbo == desafio_atual.verbo_esperado


func _desafio_atual() -> DesafioConfig:
	if _indice_desafio < 0 or _indice_desafio >= configuracao.desafios.size():
		return null
	return configuracao.desafios[_indice_desafio]


## Os desafios sao percorridos em ciclo, e nao ate acabar.
##
## O motivo e a mecanica de cores: a protecao dura poucos segundos e cada
## desafio concede a cifra DELE, entao um jogador que ja resolveu tudo precisaria
## atravessar o resto do labirinto em texto claro, sem nenhum comando disponivel
## para se defender de um cachorro que apareca no caminho. Voltando ao primeiro
## desafio, o terminal continua sendo uma ferramenta ate o fim da fase -- e como
## resolver de novo nao pontua (ver _ao_submeter_comando), o placar continua
## medindo aprendizado e nao repeticao.
func _avancar_desafio() -> void:
	var resolvido: DesafioConfig = _desafio_atual()
	if resolvido != null:
		_desafios_resolvidos[resolvido.identificador] = true

	_indice_desafio += 1
	_numero_tentativa_do_desafio = 1

	if _indice_desafio >= configuracao.desafios.size():
		_indice_desafio = 0
		if _desafios_resolvidos.size() >= configuracao.desafios.size():
			# "Desafios", nao "pacotes": a porta depende dos pacotes (perguntas),
			# e dizer "va ate a porta" aqui mandava o jogador a uma porta trancada.
			terminal.escrever("todos os desafios de cifra desta fase ja foram resolvidos. "
				+ "os comandos continuam valendo para se proteger no caminho.")

	var proximo: DesafioConfig = _desafio_atual()
	if proximo != null:
		terminal.escrever("proximo desafio (%s): %s"
			% [LegendaCores.nome(proximo.algoritmo_efetivo(configuracao.algoritmo)), proximo.enunciado])


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

## Os limites saem de TileMapLayer.get_used_rect(), e nao de constante nenhuma:
## trocar o desenho do labirinto reajusta a camera sozinho.
##
## Duas situacoes, decididas por medida e nao por fase: se o labirinto inteiro
## cabe na viewport (o caso das tres fases atuais -- 25x19 tiles de 16 = 400x304
## numa viewport de 640x360), a camera fica FIXA no centro do mapa e o jogador
## enxerga o labirinto todo, que e o enquadramento certo para um jogo de rota e
## perseguicao: esconder metade do mapa so tornaria o cachorro injusto. Se um
## mapa futuro passar do tamanho da tela, a camera volta a seguir o jogador,
## agora presa aos limites -- sem nunca mostrar o vazio fora do labirinto.
func _configurar_camera() -> void:
	var regiao: Rect2i = labirinto.get_used_rect()
	if regiao.size == Vector2i.ZERO or labirinto.tile_set == null:
		return

	var tamanho_tile: Vector2i = labirinto.tile_set.tile_size
	var canto: Vector2 = labirinto.to_global(Vector2(regiao.position * tamanho_tile))
	var tamanho_mundo: Vector2 = Vector2(regiao.size * tamanho_tile)
	var tamanho_visivel: Vector2 = get_viewport_rect().size / camera.zoom

	camera.limit_left = int(canto.x)
	camera.limit_top = int(canto.y)
	camera.limit_right = int(canto.x + tamanho_mundo.x)
	camera.limit_bottom = int(canto.y + tamanho_mundo.y)

	_camera_segue_jogador = (tamanho_mundo.x > tamanho_visivel.x
		or tamanho_mundo.y > tamanho_visivel.y)
	if not _camera_segue_jogador:
		camera.position_smoothing_enabled = false
		camera.global_position = canto + tamanho_mundo * 0.5


# ---------------------------------------------------------------------------
# Mapa: o texto de MapaConfig vira o labirinto e as posicoes
# ---------------------------------------------------------------------------

## Repinta o TileMapLayer a partir do texto e leva entrada e saida para as
## celulas marcadas nele. Fase sem MapaConfig fica exatamente como era: o
## labirinto pintado no .tscn e os marcadores onde a cena os colocou.
##
## Repintar em vez de confiar no que o .tscn traz nao e redundancia inutil: o
## desenho do .tscn e GERADO do mesmo texto (tools/gerar_fase_0N.gd chama o
## mesmo MapaConfig.pintar), entao repintar aqui garante que editar o texto e
## esquecer de regerar a cena nao produza um jogo diferente do que o validador
## conferiu. O texto e a fonte; o resto e derivado.
func _aplicar_mapa() -> void:
	if configuracao.mapa == null:
		return

	configuracao.mapa.pintar(labirinto)

	var celula_de_entrada: Vector2i = configuracao.mapa.celula_unica(MapaConfig.JOGADOR)
	if celula_de_entrada.x >= 0:
		ponto_de_entrada.global_position = _mundo_da_celula(celula_de_entrada)

	var celula_de_saida: Vector2i = configuracao.mapa.celula_unica(MapaConfig.SAIDA)
	if celula_de_saida.x >= 0:
		ponto_de_saida.global_position = _mundo_da_celula(celula_de_saida)


## A celula onde a entidade de indice `indice` nasce: do desenho, quando ha
## MapaConfig; do campo `celula` do proprio config, quando nao ha.
func _celula_do_mapa(marcador: String, indice: int, alternativa: Vector2i) -> Vector2i:
	if configuracao.mapa == null:
		return alternativa
	var celulas: Array[Vector2i] = configuracao.mapa.celulas_de(marcador)
	return celulas[indice] if indice < celulas.size() else alternativa


# ---------------------------------------------------------------------------
# Cachorros: criacao a partir do dado da fase
# ---------------------------------------------------------------------------

## Um cachorro por item de FaseConfig.cachorros. O primeiro reaproveita o no que
## ja existe em fase_base.tscn (por isso nenhuma fase precisa instanciar o
## cachorro numero 1); os demais sao instancias da mesma cena, o que mantem
## colisao, area de contato e raio de visao identicos entre eles.
##
## Lista vazia = a fase usa so o cachorro da cena, exigindo o algoritmo da
## propria fase. E o comportamento que existia antes de a lista existir, e ele
## continua valendo para nao obrigar nenhuma fase a declarar dado novo.
func _configurar_cachorros() -> void:
	cachorros.clear()
	_config_por_cachorro.clear()
	_visao_por_cachorro.clear()
	_ancora_por_cachorro.clear()

	if configuracao.cachorros.is_empty():
		_preparar_cachorro(cachorro, null)
		return

	var cena: PackedScene = load(_CENA_DO_CACHORRO) as PackedScene
	for i: int in configuracao.cachorros.size():
		var alvo: Cachorro = cachorro
		if i > 0:
			alvo = cena.instantiate() as Cachorro
			alvo.name = "Cachorro%d" % (i + 1)
			add_child(alvo)
		_preparar_cachorro(alvo, configuracao.cachorros[i], i)


func _preparar_cachorro(alvo: Cachorro, config_do_cachorro: CachorroConfig, indice: int = 0) -> void:
	var algoritmo: String = configuracao.algoritmo
	var velocidade: float = configuracao.velocidade_cachorro
	var alcance: float = configuracao.alcance_deteccao_cachorro

	if config_do_cachorro != null:
		algoritmo = config_do_cachorro.algoritmo_exigido
		alvo.identificador = config_do_cachorro.identificador
		if config_do_cachorro.velocidade > 0.0:
			velocidade = config_do_cachorro.velocidade
		if config_do_cachorro.alcance_deteccao > 0.0:
			alcance = config_do_cachorro.alcance_deteccao
		alvo.comando_para_bloquear = config_do_cachorro.comando_para_bloquear.strip_edges()
		alvo.global_position = _mundo_da_celula(
			_celula_do_mapa(MapaConfig.CACHORRO, indice, config_do_cachorro.celula_inicial))
	_nascimento_por_cachorro[alvo] = alvo.global_position

	alvo.velocidade = velocidade
	alvo.alcance_deteccao = alcance
	alvo.definir_algoritmo(algoritmo)
	alvo.definir_cor(config_do_cachorro.cor_efetiva() if config_do_cachorro != null
		else LegendaCores.cor(algoritmo))
	alvo.contato_com_jogador.connect(_ao_encostar_no_jogador.bind(alvo))

	cachorros.append(alvo)
	_config_por_cachorro[alvo] = config_do_cachorro
	_visao_por_cachorro[alvo] = false
	_ancora_por_cachorro[alvo] = 0


## Uma linha por vigia, na cor dele: o que o jogador precisa digitar, ou que
## aquele nao tem comando. So os vigias de comando e os que so perseguem
## entram -- vigia de cifra (fases de cifra) se resolve pelo desafio.
func _legenda_de_comandos() -> Array[Dictionary]:
	var itens: Array[Dictionary] = []
	for alvo: Cachorro in cachorros:
		if alvo.bloqueia_por_comando():
			itens.append({"cor": alvo.cor(), "texto": alvo.comando_para_bloquear})
		elif _apenas_persegue(alvo):
			itens.append({"cor": alvo.cor(), "texto": "sem comando: fuja"})
		else:
			var config_do_cachorro: CachorroConfig = _config_por_cachorro.get(alvo) as CachorroConfig
			if config_do_cachorro != null and not config_do_cachorro.comando_da_cifra().is_empty():
				itens.append({"cor": alvo.cor(), "texto": config_do_cachorro.comando_da_cifra()})
	return itens


func _mundo_da_celula(celula: Vector2i) -> Vector2:
	return labirinto.to_global(labirinto.map_to_local(celula))


# ---------------------------------------------------------------------------
# Pacotes e caixa de puzzle (modo humano)
# ---------------------------------------------------------------------------

## Um Pacote por item de FaseConfig.pacotes, posicionado pela celula. Fase sem
## pacotes tem a porta destrancada desde o inicio -- e o comportamento anterior
## a esta mecanica, que continua valendo para qualquer fase que nao declare
## pacote nenhum.
func _configurar_pacotes() -> void:
	pacotes.clear()
	_pacotes_coletados = 0
	_tentativas_por_pacote.clear()

	# As POSICOES saem da lista na ordem declarada (foram escolhidas para ficarem
	# espalhadas pelo mapa); as PERGUNTAS sao sorteadas entre si e distribuidas
	# por essas posicoes. O jogador ve sempre as mesmas perguntas da fase --
	# nenhum participante recebe um instrumento diferente do outro, que e o que
	# a validade interna do experimento exige --, mas nao decora "no canto
	# nordeste a resposta e Cesar" de uma partida para a outra.
	var celulas: Array[Vector2i] = []
	var perguntas: Array[PacoteConfig] = []
	for i: int in configuracao.pacotes.size():
		var config_do_pacote: PacoteConfig = configuracao.pacotes[i]
		celulas.append(_celula_do_mapa(MapaConfig.PACOTE, i, config_do_pacote.celula))
		perguntas.append(config_do_pacote)
	perguntas.shuffle()

	var cena: PackedScene = load(_CENA_DO_PACOTE) as PackedScene
	for i: int in perguntas.size():
		var config_do_pacote: PacoteConfig = perguntas[i]
		var pacote: Pacote = cena.instantiate() as Pacote
		pacote.name = "Pacote_%s" % config_do_pacote.identificador
		pacotes_no.add_child(pacote)
		pacote.global_position = _mundo_da_celula(celulas[i])
		pacote.definir(config_do_pacote)
		pacote.alcancado.connect(_ao_alcancar_pacote)
		pacotes.append(pacote)

	ponto_de_saida.definir_trancada(_porta_trancada())
	hud.mostrar_pacotes(_pacotes_coletados, pacotes.size())


## Encostar num pacote abre a pergunta -- exceto em modo de treino, onde o
## pacote e coletado na hora. A caixa exige ler e clicar; um agente de
## aprendizado por reforco nao faz nem uma coisa nem outra, e travar o episodio
## numa tela modal quebraria o treino sem ensinar nada a ninguem.
func _ao_alcancar_pacote(pacote: Pacote) -> void:
	if _encerrada or pacote.coletado:
		return

	if ConfigJogo.modo_treino:
		_coletar_pacote(pacote)
		return

	_pacote_em_puzzle = pacote
	jogador.definir_entrada_habilitada(false)
	# A caixa tem process_mode ALWAYS (cenas/base/caixa_puzzle.tscn), entao ela
	# continua respondendo com a arvore pausada -- e a pausa e o que impede um
	# cachorro de capturar o jogador enquanto ele le o enunciado.
	get_tree().paused = true
	caixa_puzzle.abrir(pacote.configuracao)


## O puzzle entra na telemetria como tentativa_comando, e so.
##
## Nao ha evento novo porque o catalogo e fechado pelo banco (restricao 7 da
## secao 4 do CLAUDE.md: FK para pesquisa.tipo_evento), e um codigo inventado
## aqui viraria INSERT rejeitado la -- dado de pesquisa perdido. E nao ha
## COMANDO_SUBMETIDO porque o terminal tambem nao emite: a convencao do projeto
## e que cada comando submetido JA e uma linha de tentativa_comando, e duplicar
## so o do puzzle desalinharia a contagem entre as duas origens.
##
## O desafio vai prefixado com "pacote-", que e o que permite a analise separar
## "escolheu a ferramenta certa" (aqui) de "operou a cifra certa" (terminal) --
## sao competencias diferentes e o pre/pos-teste mede as duas.
func _ao_responder_puzzle(correto: bool, opcao: String, tempo_resposta_ms: int) -> void:
	if _pacote_em_puzzle == null:
		return

	var config_do_pacote: PacoteConfig = _pacote_em_puzzle.configuracao
	var identificador: String = "pacote-%s" % config_do_pacote.identificador
	var tentativa: int = int(_tentativas_por_pacote.get(identificador, 1))

	Telemetria.registrar_tentativa(
		configuracao.numero,
		identificador,
		opcao,
		[],
		CatalogoResultados.SUCESSO if correto else CatalogoResultados.ERRO_SEMANTICO,
		"" if correto else "opcao_incorreta",
		tempo_resposta_ms,
		tentativa)

	if not correto:
		_tentativas_por_pacote[identificador] = tentativa + 1
		Sessao.somar_pontos(-config_do_pacote.penalidade_erro)
		return

	Sessao.somar_pontos(config_do_pacote.pontos_acerto)
	var coletado: Pacote = _pacote_em_puzzle
	_fechar_puzzle()
	_coletar_pacote(coletado)


func _fechar_puzzle() -> void:
	_pacote_em_puzzle = null
	caixa_puzzle.fechar()
	get_tree().paused = false
	if not _encerrada:
		jogador.definir_entrada_habilitada(true)


## A pausa e da ARVORE inteira, nao desta cena: sair da fase com a caixa aberta
## (concluir, abandonar ou falhar) levaria a pausa junto para o menu, que
## ficaria congelado. Isto e a rede de seguranca contra esse vazamento.
func _garantir_jogo_despausado() -> void:
	if caixa_puzzle != null and caixa_puzzle.esta_aberta():
		caixa_puzzle.fechar()
	if terminal != null and terminal.esta_aberto():
		terminal.fechar()
	if painel_pause != null and painel_pause.esta_aberto():
		painel_pause.fechar()
	_pacote_em_puzzle = null
	get_tree().paused = false


# ---------------------------------------------------------------------------
# Menu de pause
# ---------------------------------------------------------------------------

func _abrir_pause() -> void:
	painel_pause.abrir()
	get_tree().paused = true


## "Continuar" ou ESC de novo: so despausa. "Reiniciar" e "voltar ao menu" vao
## direto para reiniciar()/abandonar(), que ja despausam por conta propria via
## _registrar_abandono() -> _garantir_jogo_despausado().
func _ao_fechar_pause() -> void:
	get_tree().paused = false


func _coletar_pacote(pacote: Pacote) -> void:
	pacote.coletar()
	_pacotes_coletados += 1
	hud.mostrar_pacotes(_pacotes_coletados, pacotes.size())

	if _porta_trancada():
		terminal.escrever("pacote coletado (%d de %d). a porta ainda esta trancada."
			% [_pacotes_coletados, pacotes.size()])
		return

	ponto_de_saida.definir_trancada(false)
	terminal.escrever("todos os pacotes coletados. a porta se abriu -- siga para a saida.")


# ---------------------------------------------------------------------------
# IA do cachorro: replanejamento (AStarGrid2D via Navegacao) e deteccao
# ---------------------------------------------------------------------------

func _configurar_temporizador_replanejamento() -> void:
	_temporizador_replanejamento = Timer.new()
	_temporizador_replanejamento.name = "TemporizadorDeReplanejamento"
	# Timer nao aceita wait_time 0 -- e o mesmo piso defensivo que Telemetria
	# aplica ao intervalo de descarga, pelo mesmo motivo: um FaseConfig com 0.0
	# nao pode virar recalculo por quadro (secao 6: "replanejamento por
	# intervalo, nao por quadro").
	_temporizador_replanejamento.wait_time = maxf(0.05, configuracao.intervalo_replanejamento_s)
	_temporizador_replanejamento.autostart = true
	_temporizador_replanejamento.timeout.connect(_replanejar_caminho_do_cachorro)
	add_child(_temporizador_replanejamento)


## Um replanejamento por cachorro, todos no mesmo tique do temporizador. Cada
## chamada de A* entra separada na media de AMOSTRA_DESEMPENHO: o numero que
## interessa ao Eixo 7 e o custo de UMA busca, para a conta "n cachorros x custo
## por busca" continuar valendo quando uma fase futura tiver mais cachorros.
func _replanejar_caminho_do_cachorro() -> void:
	if _encerrada:
		return
	for alvo: Cachorro in cachorros:
		var inicio_us: int = Time.get_ticks_usec()
		var caminho: PackedVector2Array = _navegacao.calcular_caminho(
			alvo.global_position, _alvo_de_perseguicao(alvo))
		_soma_replanejamento_us += Time.get_ticks_usec() - inicio_us
		_contagem_replanejamento += 1
		alvo.definir_caminho(caminho)

		# Alvo sem rota (regiao separada, por exemplo): avanca a varredura em
		# vez de insistir no mesmo ponto inalcancavel para sempre. E o segundo
		# fecho do travamento -- o primeiro e mandar so pontos andaveis.
		if caminho.is_empty() and _diretor != null:
			_indice_varredura += 1

	if _depuracao_astar_visivel:
		queue_redraw()


## CACHORRO_DETECTOU/CACHORRO_PERDEU sao emitidos na borda de subida/descida da
## linha de visao, checada a cada quadro (a deteccao tem que ser tao responsiva
## quanto o jogo, mesmo com o replanejamento do A* rodando so por intervalo).
func _atualizar_deteccao_do_cachorro() -> void:
	var algum_enxerga: bool = false
	for alvo: Cachorro in cachorros:
		var visivel: bool = alvo.tem_linha_de_visao(jogador.global_position)
		var enxergava: bool = bool(_visao_por_cachorro.get(alvo, false))

		if visivel and not enxergava:
			Telemetria.registrar_evento(CatalogoEventos.CACHORRO_DETECTOU, {
				"cachorro": alvo.identificador,
				"algoritmo_exigido": alvo.algoritmo_exigido,
				"posicao": jogador.global_position,
			}, configuracao.numero)
		elif not visivel and enxergava:
			Telemetria.registrar_evento(CatalogoEventos.CACHORRO_PERDEU,
				{"cachorro": alvo.identificador}, configuracao.numero)

		_visao_por_cachorro[alvo] = visivel
		algum_enxerga = algum_enxerga or visivel

	_cachorro_com_linha_de_visao = algum_enxerga


## O alvo que o A* persegue, na ordem de prioridade:
##
## 1. linha de visao direta -- o cachorro viu o jogador de verdade, nao ha razao
##    para fingir que nao sabe onde ele esta;
## 2. alvo do Diretor (Marco 2, fase com regioes): a crenca, nunca a posicao;
## 3. rota de patrulha (CachorroConfig.ancoras): o cachorro anda o circuito dele
##    sem saber nada sobre o jogador -- e o que da vida ao mapa quando ninguem
##    esta sendo perseguido;
## 4. sem regioes e sem ancoras: persegue a posicao real, que e o comportamento
##    original do Marco 1 preservado (docs/decisoes/0007, decisao 1).
func _alvo_de_perseguicao(alvo: Cachorro) -> Vector2:
	if alvo.tem_linha_de_visao(jogador.global_position):
		return jogador.global_position

	if _diretor != null:
		var regiao: Area2D = _diretor.regiao_mais_provavel()
		return _alvo_de_varredura(alvo, regiao) if regiao != null else alvo.global_position

	if not _ancoras_de(alvo).is_empty():
		return _alvo_de_patrulha(alvo)

	return jogador.global_position


func _ancoras_de(alvo: Cachorro) -> Array[Vector2i]:
	var config_do_cachorro: CachorroConfig = _config_por_cachorro.get(alvo) as CachorroConfig
	return config_do_cachorro.ancoras if config_do_cachorro != null else [] as Array[Vector2i]


## Patrulha em ciclo pelas ancoras da fase. O indice so avanca quando o cachorro
## CHEGA na ancora -- avancar por tempo faria ele abandonar pontos que ainda nao
## alcancou e trocar a rota por um passeio aleatorio.
##
## A tolerancia e o dobro da de chegada porque a ancora e o centro de uma celula
## e o replanejamento roda por intervalo: exigir o pixel exato deixaria o
## cachorro girando em torno do ponto ate o proximo tique.
func _alvo_de_patrulha(alvo: Cachorro) -> Vector2:
	var ancoras: Array[Vector2i] = _ancoras_de(alvo)
	var indice: int = int(_ancora_por_cachorro.get(alvo, 0))
	var destino: Vector2 = _mundo_da_celula(ancoras[indice % ancoras.size()])

	if alvo.global_position.distance_to(destino) <= alvo.tolerancia_de_chegada * 2.0:
		indice += 1
		_ancora_por_cachorro[alvo] = indice
		destino = _mundo_da_celula(ancoras[indice % ancoras.size()])

	# Mesma protecao da varredura: uma ancora mal colocada (em parede) travaria
	# o cachorro no lugar em vez de so desviar a rota. MapaConfig.problemas()
	# ja recusa a fase nesse caso; isto e a rede para as fases sem MapaConfig.
	return _navegacao.ponto_andavel_mais_proximo(destino)


## Comportamento de caca local (secao 7 do CLAUDE.md): ao chegar perto do
## centro da regiao-alvo do Diretor, o cachorro varre alguns pontos ao redor
## em vez de ficar parado em cima do centro -- ate ganhar contato visual ou o
## Diretor mudar de alvo (o que reseta a varredura via alvo_alterado).
const _OFFSETS_DE_VARREDURA: Array[Vector2] = [
	Vector2.ZERO, Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0), Vector2(0, -16),
]


## O deslocamento inicial de cada cachorro na tabela de varredura e a posicao
## dele na lista: com dois ou tres cachorros varrendo a MESMA regiao (o Diretor
## publica um alvo so para todos), sem isso eles empilhariam no mesmo pixel e a
## varredura cobriria um ponto em vez de uma area.
func _alvo_de_varredura(alvo: Cachorro, regiao: Area2D) -> Vector2:
	var centro: Vector2 = regiao.global_position
	var deslocamento: int = maxi(0, cachorros.find(alvo))
	var total: int = _OFFSETS_DE_VARREDURA.size()
	var ponto: Vector2 = centro + _OFFSETS_DE_VARREDURA[(_indice_varredura + deslocamento) % total]
	if alvo.global_position.distance_to(ponto) <= alvo.tolerancia_de_chegada:
		_indice_varredura += 1
		ponto = centro + _OFFSETS_DE_VARREDURA[(_indice_varredura + deslocamento) % total]
	# Os offsets sao cegos ao labirinto: o centro de uma regiao pode estar
	# colado numa parede e o ponto ao lado cair dentro dela. Sem esta correcao
	# o A* devolvia caminho vazio e o cachorro travava para sempre, porque o
	# indice da varredura so avanca quando ele CHEGA ao ponto -- e nunca
	# chegaria. Ver ponto_andavel_mais_proximo em scripts/ia/navegacao.gd.
	return _navegacao.ponto_andavel_mais_proximo(ponto)


# ---------------------------------------------------------------------------
# Diretor de IA (Marco 2): regioes, pistas e decaimento
# ---------------------------------------------------------------------------

## Regioes sao dado de cena (Area2D em Marcadores/Regioes), nunca hardcoded
## aqui -- e a mesma logica de "matriz de dados" do FaseConfig. Uma fase de
## autoria nunca declara regiao, entao fica sem Diretor: ver
## _alvo_de_perseguicao.
func _configurar_diretor() -> void:
	var regioes: Array[Area2D] = []
	for filho: Node in regioes_no.get_children():
		if filho is Area2D:
			regioes.append(filho as Area2D)
			(filho as Area2D).body_entered.connect(_ao_jogador_entrar_na_regiao.bind(filho))
			(filho as Area2D).body_exited.connect(_ao_jogador_sair_da_regiao.bind(filho))

	if regioes.is_empty():
		return

	_diretor = Diretor.new(
		regioes,
		configuracao.peso_pista_comando_errado,
		configuracao.peso_pista_movimento,
		configuracao.peso_pista_captura,
		configuracao.decaimento_crenca_por_s)
	_diretor.alvo_alterado.connect(func(_r: Area2D) -> void: _indice_varredura = 0)

	_temporizador_diretor = Timer.new()
	_temporizador_diretor.name = "TemporizadorDoDiretor"
	_temporizador_diretor.wait_time = maxf(0.05, configuracao.intervalo_decisao_diretor_s)
	_temporizador_diretor.autostart = true
	_temporizador_diretor.timeout.connect(_ao_vencer_temporizador_do_diretor)
	add_child(_temporizador_diretor)


func _ao_vencer_temporizador_do_diretor() -> void:
	if _encerrada or _diretor == null:
		return
	_diretor.decair(_temporizador_diretor.wait_time)


# ---------------------------------------------------------------------------
# Instrumentacao de desempenho (Marco 3): AMOSTRA_DESEMPENHO a cada 30s
# ---------------------------------------------------------------------------

func _configurar_temporizador_desempenho() -> void:
	_temporizador_desempenho = Timer.new()
	_temporizador_desempenho.name = "TemporizadorDeDesempenho"
	_temporizador_desempenho.wait_time = _INTERVALO_AMOSTRA_DESEMPENHO_S
	_temporizador_desempenho.autostart = true
	_temporizador_desempenho.timeout.connect(_ao_vencer_temporizador_de_desempenho)
	add_child(_temporizador_desempenho)


## FPS, memoria estatica e objetos desenhados vem de Performance.get_monitor()
## (ferramenta nativa, secao 2 do CLAUDE.md); o tempo medio de replanejamento
## do A* e o unico numero que so este arquivo pode medir, porque so ele sabe
## quando cada replanejamento comeca e termina. Junto, os quatro respondem
## "a IA cabe no orcamento de quadro?" com numero, nao com impressao.
func _ao_vencer_temporizador_de_desempenho() -> void:
	if _encerrada:
		return

	var media_replanejamento_ms: float = 0.0
	if _contagem_replanejamento > 0:
		media_replanejamento_ms = (float(_soma_replanejamento_us) / float(_contagem_replanejamento)) / 1000.0

	Telemetria.registrar_evento(CatalogoEventos.AMOSTRA_DESEMPENHO, {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"memoria_estatica_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"objetos_desenhados": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"replanejamento_medio_ms": media_replanejamento_ms,
	}, configuracao.numero)

	_soma_replanejamento_us = 0
	_contagem_replanejamento = 0


## Pista fraca, disparada uma vez por entrada na regiao (nao a cada quadro
## parado dentro dela) -- reforcar continuamente equivaleria a entregar a
## posicao quase exata ao Diretor, o que contradiria a propria premissa da
## informacao imperfeita.
func _ao_jogador_entrar_na_regiao(corpo: Node2D, regiao: Area2D) -> void:
	if not (corpo is Jogador):
		return
	_regiao_atual_do_jogador = regiao
	if _diretor != null:
		_diretor.pista_movimento(regiao)


func _ao_jogador_sair_da_regiao(corpo: Node2D, regiao: Area2D) -> void:
	if not (corpo is Jogador):
		return
	if _regiao_atual_do_jogador == regiao:
		_regiao_atual_do_jogador = null


# ---------------------------------------------------------------------------
# Painel de demonstracao da cifra (Marco 2)
# ---------------------------------------------------------------------------

## Mostra um exemplo FIXO (FaseConfig.texto/chave_exemplo_demonstracao), nunca
## o desafio corrente -- o painel ensina o MECANISMO da cifra, nao e um jeito
## de espiar a chave que resolve o desafio ativo (isso ja existe, com custo:
## o verbo "dica"). Ver docs/decisoes/0008-vigenere-e-painel-de-demonstracao.md.
##
## SHA256 nao tem chave nem "desloca letra por letra" -- a demonstracao dele e
## o efeito avalanche (docs/decisoes/0009), entao o painel muda de conteudo
## por algoritmo aqui, mas continua sendo o MESMO no e o MESMO evento.
func _alternar_painel_de_demonstracao() -> void:
	if painel_cifra.esta_aberto():
		painel_cifra.fechar()
		return

	if configuracao.texto_exemplo_demonstracao.is_empty():
		terminal.escrever("esta fase nao tem exemplo de demonstracao configurado.")
		return

	if configuracao.algoritmo == "SHA256":
		var texto_a: String = configuracao.texto_exemplo_demonstracao
		var texto_b: String = texto_a + texto_a[texto_a.length() - 1]
		painel_cifra.abrir_avalanche("efeito avalanche: um caractere a mais muda tudo", texto_a, texto_b)
	else:
		if configuracao.chave_exemplo_demonstracao.is_empty():
			terminal.escrever("esta fase nao tem exemplo de demonstracao configurado.")
			return
		var cifra: Cifra = FabricaCifra.para_algoritmo(configuracao.algoritmo)
		if cifra == null:
			terminal.escrever("nao ha demonstracao disponivel para o algoritmo '%s'." % configuracao.algoritmo)
			return
		painel_cifra.abrir(
			"como o %s desloca cada letra" % configuracao.algoritmo,
			configuracao.texto_exemplo_demonstracao,
			configuracao.chave_exemplo_demonstracao,
			cifra)

	Telemetria.registrar_evento(CatalogoEventos.CIFRA_DEMONSTRADA, {
		"algoritmo": configuracao.algoritmo,
	}, configuracao.numero)


# ---------------------------------------------------------------------------
# Falha de configuracao
# ---------------------------------------------------------------------------

func _diagnosticar() -> String:
	if configuracao == null:
		return ("fase_base.tscn e a cena pai e nao roda sozinha.\n"
			+ "abra uma cena herdada (cenas/fases/fase_0N.tscn) ou atribua um\n"
			+ "FaseConfig no Inspector, no campo 'configuracao'.")

	var problemas: PackedStringArray = configuracao.problemas()
	if not problemas.is_empty():
		return "FaseConfig invalido:\n- %s" % "\n- ".join(problemas)

	return ""


func _falhar(mensagem: String) -> void:
	Registro.erro("FaseBase", mensagem.replace("\n", " "))
	_rotulo_do_aviso.text = mensagem
	aviso.visible = true
	set_physics_process(false)
	# Sem desligar os filhos, o jogador andaria por um labirinto sem regra
	# nenhuma atras da mensagem de erro.
	jogador.definir_entrada_habilitada(false)
	# _falhar roda antes de _configurar_cachorros, entao `cachorros` ainda esta
	# vazia: quem precisa parar aqui e o cachorro da propria cena.
	cachorro.parar()


func _voltar_ao_menu() -> void:
	get_tree().change_scene_to_file(CENA_DO_MENU)
