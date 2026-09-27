class_name Diretor
extends RefCounted

## Camada de informação imperfeita do cachorro farejador (Marco 2).
##
## Inspiração declarada (seção 7 do CLAUDE.md): o sistema de dois cérebros de
## *Alien: Isolation*. O Diretor é o "cérebro" que nunca sabe onde o jogador
## está de verdade -- só mantém uma CRENÇA (distribuição de probabilidade)
## sobre em qual REGIÃO do mapa o jogador provavelmente está, atualizada por
## PISTAS. O outro cérebro (percepção direta por linha de visão) mora em
## Cachorro.tem_linha_de_visao() e é decidido por FaseBase, não por aqui.
##
## GARANTIA ESTRUTURAL, não só de convenção: nenhum método desta classe aceita
## um Vector2 de posição do jogador. Toda pista chega como uma REGIÃO (um nó
## Area2D já existente na cena, colocado pelo editor) ou como um evento sem
## posição nenhuma (decaimento). Quem observa overlap de Area2D e decide qual
## região o jogador está é FaseBase -- este arquivo só agrega o que chega.
##
## Sem aleatoriedade: a crença é uma média ponderada determinística das
## pistas recebidas. O "mesmo roteiro de pistas -> mesmo alvo" do critério de
## aceite do Marco 2 é automático, não depende de semente nenhuma -- registrado
## em docs/decisoes/0002-diretor-ia.md.

signal alvo_alterado(regiao: Area2D)

var _regioes: Array[Area2D] = []
var _crenca: Dictionary = {}  # Area2D -> float, distribuicao normalizada (soma 1.0)

var _peso_pista_forte: float
var _peso_pista_fraca: float
var _peso_pista_captura: float
var _decaimento_por_s: float

var _regiao_alvo_atual: Area2D = null


func _init(
		regioes: Array[Area2D],
		peso_pista_comando_errado: float,
		peso_pista_movimento: float,
		peso_pista_captura: float,
		decaimento_crenca_por_s: float) -> void:
	_regioes = regioes
	_peso_pista_forte = peso_pista_comando_errado
	_peso_pista_fraca = peso_pista_movimento
	_peso_pista_captura = peso_pista_captura
	_decaimento_por_s = decaimento_crenca_por_s
	_zerar_crenca()
	_recalcular_alvo()


## Pista forte: um comando errado no terminal aconteceu enquanto o jogador
## estava em `regiao`. É informação real (a fase sabe onde o jogador está
## fisicamente ao processar o comando) traduzida em crença -- não em posição.
func pista_comando_errado(regiao: Area2D) -> void:
	_reforcar(regiao, _peso_pista_forte)


## Pista fraca: o jogador foi observado se movendo por dentro de `regiao` (um
## corredor aberto não denuncia tanto quanto um erro no terminal).
func pista_movimento(regiao: Area2D) -> void:
	_reforcar(regiao, _peso_pista_fraca)


## Reforço: uma captura acabou de acontecer em `regiao`. É a pista mais forte
## porque é um evento físico (contato), não uma inferência.
func pista_captura(regiao: Area2D) -> void:
	_reforcar(regiao, _peso_pista_captura)


## Decaimento por tempo: sem pista nova, a crença relaxa de volta para a
## distribuição uniforme -- é o que representa "faz tempo que não se sabe de
## nada", em vez de a crença ficar presa para sempre na última pista.
func decair(delta_s: float) -> void:
	if _regioes.is_empty() or delta_s <= 0.0:
		return
	var uniforme: float = 1.0 / _regioes.size()
	var fator: float = clampf(_decaimento_por_s * delta_s, 0.0, 1.0)
	for regiao: Area2D in _regioes:
		_crenca[regiao] = lerpf(float(_crenca[regiao]), uniforme, fator)
	_normalizar()
	_recalcular_alvo()


## Região com maior crença no momento. Empate se resolve pela primeira região
## na ordem de `_regioes` (ordem de filhos na cena -- determinístico).
func regiao_mais_provavel() -> Area2D:
	return _regiao_alvo_atual


## Centro da região mais provável, em coordenadas de mundo. É a ÚNICA posição
## que este objeto produz, e vem do marcador da cena (dado de editor), nunca
## do jogador.
func alvo_atual() -> Vector2:
	return _regiao_alvo_atual.global_position if _regiao_alvo_atual != null else Vector2.ZERO


func crenca_da_regiao(regiao: Area2D) -> float:
	return float(_crenca.get(regiao, 0.0))


func _reforcar(regiao: Area2D, peso: float) -> void:
	if not _crenca.has(regiao) or peso <= 0.0:
		return
	_crenca[regiao] = float(_crenca[regiao]) + peso
	_normalizar()
	_recalcular_alvo()


func _normalizar() -> void:
	var soma: float = 0.0
	for regiao: Area2D in _regioes:
		soma += float(_crenca[regiao])
	if soma <= 0.0:
		_zerar_crenca()
		return
	for regiao: Area2D in _regioes:
		_crenca[regiao] = float(_crenca[regiao]) / soma


func _zerar_crenca() -> void:
	_crenca.clear()
	if _regioes.is_empty():
		return
	var uniforme: float = 1.0 / _regioes.size()
	for regiao: Area2D in _regioes:
		_crenca[regiao] = uniforme


func _recalcular_alvo() -> void:
	if _regioes.is_empty():
		_regiao_alvo_atual = null
		return

	var melhor: Area2D = _regioes[0]
	var melhor_peso: float = float(_crenca[melhor])
	for regiao: Area2D in _regioes:
		var peso: float = float(_crenca[regiao])
		if peso > melhor_peso:
			melhor = regiao
			melhor_peso = peso

	if melhor != _regiao_alvo_atual:
		_regiao_alvo_atual = melhor
		alvo_alterado.emit(_regiao_alvo_atual)
