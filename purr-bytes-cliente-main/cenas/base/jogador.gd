class_name Jogador
extends CharacterBody2D

## O jogador transporta o pacote de dados pelo labirinto -- que representa a
## topologia da rede. Em texto claro ele e interceptavel; com a cifra ativa, nao.
##
## Movimento com CharacterBody2D + move_and_slide(): a colisao com as paredes sai
## do TileSet, entao o labirinto desenhado no editor ja e o labirinto jogavel,
## sem nenhuma tabela de colisao paralela para manter sincronizada.
##
## Este no nao conhece a fase. Ele emite sinais e expoe estado; quem decide
## consequencia e fase_base.gd (secao 9: sinal de baixo para cima).

signal protecao_alterada(ativa: bool, restante_s: float, algoritmo: String)
signal protecao_expirou()

@export_range(10.0, 200.0, 1.0) var velocidade: float = 70.0

## Aceleracao alta de proposito: labirinto com corredor estreito fica
## intoleravel com inercia. Nao e realismo, e legibilidade de controle.
@export_range(1.0, 60.0, 0.5) var resposta: float = 20.0

var protecao_ativa: bool = false

## QUAL cifra esta ativa, nao apenas "esta cifrado". E o que permite a regra da
## fase decidir se ela engana ou nao um cachorro de determinada cor: cifrar com
## Cesar nao protege de um interceptador que le Vigenere, e essa distincao e a
## licao inteira da mecanica de cores.
var algoritmo_protegido: String = ""

## O COMANDO livre que produziu a protecao, nas fases de autoria. Convive com
## algoritmo_protegido porque os dois modos coexistem: as fases 1 a 3 protegem
## por cifra, as fases criadas no editor protegem pelo comando que o professor
## escreveu. Vazio quando a protecao veio por cifra (ou quando nao ha protecao).
var comando_protegido: String = ""

var _restante_de_protecao_s: float = 0.0

@onready var _sprite: AnimadorDirecional = $Sprite
var _entrada_habilitada: bool = true

## Pedido da Day: depois de tempo_sem_entrada_para_descansar_s sem NENHUMA
## tecla de movimento (nao so parado por um instante entre passos), o gato
## senta e descansa em vez de continuar no "parado" de olho aberto -- e volta
## ao normal no primeiro input. @export por causa da secao 9 do CLAUDE.md
## (zero numero magico): e um valor de balanceamento, nao implementacao.
@export_range(1.0, 60.0, 0.5) var tempo_sem_entrada_para_descansar_s: float = 10.0

var _tempo_sem_entrada_s: float = 0.0
var _descansando: bool = false

@onready var _zzz: Label = $Zzz
var _tween_do_zzz: Tween = null


func _physics_process(delta: float) -> void:
	if _restante_de_protecao_s > 0.0:
		_restante_de_protecao_s = maxf(0.0, _restante_de_protecao_s - delta)
		protecao_alterada.emit(true, _restante_de_protecao_s, algoritmo_protegido)
		if is_zero_approx(_restante_de_protecao_s):
			protecao_ativa = false
			algoritmo_protegido = ""
			comando_protegido = ""
			protecao_alterada.emit(false, 0.0, "")
			protecao_expirou.emit()

	var direcao: Vector2 = Vector2.ZERO
	if _entrada_habilitada:
		# Input.get_vector ja normaliza e ja resolve teclas opostas apertadas
		# juntas -- nao ha motivo para reimplementar isso.
		direcao = Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")

	velocity = velocity.lerp(direcao * velocidade, clampf(resposta * delta, 0.0, 1.0))
	move_and_slide()
	_atualizar_descanso(direcao, delta)


## direcao e o INPUT bruto (antes do lerp), nao a velocity: e a intencao do
## jogador que conta como "mexeu", nao o resíduo de inercia enquanto o corpo
## ainda esta freando depois de soltar a tecla.
func _atualizar_descanso(direcao: Vector2, delta: float) -> void:
	if direcao != Vector2.ZERO:
		_tempo_sem_entrada_s = 0.0
		if _descansando:
			_sair_do_descanso()
		_sprite.atualizar(velocity)
		return

	_tempo_sem_entrada_s += delta
	if not _descansando and _tempo_sem_entrada_s >= tempo_sem_entrada_para_descansar_s:
		_entrar_em_descanso()

	if _descansando:
		_sprite.descansar()
	else:
		_sprite.atualizar(velocity)


func _entrar_em_descanso() -> void:
	_descansando = true
	_zzz.visible = true
	_zzz.modulate.a = 1.0
	if _tween_do_zzz != null and _tween_do_zzz.is_valid():
		_tween_do_zzz.kill()
	# "zzz" pulsando bem devagar por cima do gato: e o substituto honesto para
	# o sprite de olho fechado -- gato_frames.tres nao tem esse quadro
	# desenhado (so as 5 animacoes originais), entao em vez de arriscar editar
	# pixel a pixel um rosto de 24x24 as cegas, o sono fica claro por este
	# indicador. Trocar por um quadro de "olho fechado" de verdade, quando
	# alguem desenhar um, e so adicionar a textura e apontar para ela aqui.
	_tween_do_zzz = create_tween().set_loops()
	_tween_do_zzz.tween_property(_zzz, "modulate:a", 0.35, 0.6)
	_tween_do_zzz.tween_property(_zzz, "modulate:a", 1.0, 0.6)


func _sair_do_descanso() -> void:
	_descansando = false
	if _tween_do_zzz != null and _tween_do_zzz.is_valid():
		_tween_do_zzz.kill()
	_zzz.visible = false
	_zzz.modulate.a = 1.0


## Chamado pela fase quando um comando de cifra e aceito. A duracao vem do
## FaseConfig: e ela que forca o jogador a reaplicar a cifra, e a repeticao com
## intencao e o ponto pedagogico da mecanica.
func ativar_protecao(duracao_s: float, algoritmo: String = "", comando: String = "") -> void:
	protecao_ativa = duracao_s > 0.0
	algoritmo_protegido = algoritmo if protecao_ativa else ""
	comando_protegido = comando if protecao_ativa else ""
	_restante_de_protecao_s = maxf(0.0, duracao_s)
	protecao_alterada.emit(protecao_ativa, _restante_de_protecao_s, algoritmo_protegido)


func cancelar_protecao() -> void:
	protecao_ativa = false
	algoritmo_protegido = ""
	comando_protegido = ""
	_restante_de_protecao_s = 0.0
	protecao_alterada.emit(false, 0.0, "")


## Usado enquanto o terminal esta aberto e na tela de captura: o jogador nao
## deve andar as cegas atras da janela de comando.
func definir_entrada_habilitada(habilitada: bool) -> void:
	_entrada_habilitada = habilitada
	if not habilitada:
		velocity = Vector2.ZERO


## Pisca durante a invulnerabilidade apos uma captura: o jogador precisa VER
## que tem alguns segundos para sair de perto. Tween e nao _process: e uma
## animacao de propriedade com fim, exatamente o que Tween resolve.
@export_range(0.05, 1.0, 0.05) var intervalo_da_piscada_s: float = 0.15

var _piscada: Tween = null


func piscar(duracao_s: float) -> void:
	if _piscada != null and _piscada.is_valid():
		_piscada.kill()
	modulate.a = 1.0
	if duracao_s <= 0.0:
		return
	var vezes: int = maxi(1, int(duracao_s / (intervalo_da_piscada_s * 2.0)))
	_piscada = create_tween().set_loops(vezes)
	_piscada.tween_property(self, "modulate:a", 0.3, intervalo_da_piscada_s)
	_piscada.tween_property(self, "modulate:a", 1.0, intervalo_da_piscada_s)


func reposicionar(destino: Vector2) -> void:
	global_position = destino
	velocity = Vector2.ZERO
