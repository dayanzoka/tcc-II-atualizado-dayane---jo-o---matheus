class_name FaseConfig
extends Resource

## O "dado" que define uma fase.
##
## Este arquivo e o coracao do requisito nao funcional da monografia: adicionar
## fase deve custar configuracao, nao codigo. Toda logica vive em
## cenas/base/fase_base.gd; a fase concreta e um .tres com estes campos mais um
## TileMapLayer desenhado no editor.
##
## Teste pratico da arquitetura: se a fase 4 (AES) precisar de um campo novo aqui
## que nao seja um valor, e nao de uma linha em verbos_permitidos, a
## generalizacao falhou -- e o lugar de consertar e fase_base.gd, nao aqui.

## Casa com CHECK (fase BETWEEN 1 AND 4) de evento_telemetria e
## tentativa_comando. Numero fora da faixa faz a telemetria da fase inteira ser
## recusada, entao validar() trata isso como erro fatal.
@export_range(1, 4) var numero: int = 1

## Identidade ESTAVEL e unica da fase (UUID v4), gerada uma vez e guardada no
## recurso. E ela que liga fase -> eventos na telemetria.
##
## Por que nao o `numero`: ele nasceu de um banco com quatro fases fixas. Numa
## ferramenta em que fases sao criadas livremente, numero deixa de ser
## identidade (duas fases podem nascer "5", uma fase pode ser reordenada) e
## amarrar a coleta a ele significa perder ou embaralhar dado. O UUID nao tem
## esse problema, e continua anonimo: e tecnico, nao diz nada sobre pessoa.
##
## Vazio = recurso antigo; garantir_id_fase() preenche na carga (migracao
## suave, sem quebrar .tres ja gravado).
@export var id_fase: String = ""

@export var titulo: String = ""

@export_enum("CESAR", "VIGENERE", "SHA256", "AES") var algoritmo: String = "CESAR"

## Verbos que o analisador aceita nesta fase. E a unica coisa que muda entre
## Cesar e Vigenere no terminal -- se mudar mais, o parser esta acoplado a fase.
@export var verbos_permitidos: PackedStringArray = ["cifrar", "decifrar", "dica", "status"]

## O labirinto, escrito como texto (ver scripts/dominio/mapa_config.gd). E ele
## que posiciona jogador, porta, pacotes e cachorros -- na ordem de leitura do
## desenho -- e que FaseBase repinta no TileMapLayer ao carregar a fase.
##
## Nulo = fase antiga, com o labirinto so pintado no .tscn e as posicoes vindo
## dos marcadores da cena e dos campos `celula` de cada config. Continua
## funcionando, mas sem validacao de alcancabilidade.
@export var mapa: MapaConfig

## Semente que gerou o mapa, quando ele veio de GeradorDeMapa. E o que permite
## reabrir uma fase de autoria e obter o MESMO labirinto: sem ela, o .json
## guardaria so as medidas e cada abertura sortearia um traçado diferente.
## 0 = mapa desenhado a mao (as fases 1 a 3).
@export var semente_do_mapa: int = 0

@export var desafios: Array[DesafioConfig] = []

## Cachorros da fase, um por cor/algoritmo exigido. Vazia = a fase usa apenas o
## cachorro que ja existe em fase_base.tscn, exigindo o algoritmo da propria
## fase -- e o comportamento anterior a esta lista, preservado de proposito para
## nenhuma fase quebrar por falta de dado novo.
@export var cachorros: Array[CachorroConfig] = []

## Pacotes de dados espalhados pelo labirinto. Cada um abre uma pergunta curta
## (cenas/base/caixa_puzzle.tscn) e so e coletado com a resposta certa; a porta
## de saida fica trancada ate todos serem coletados. Lista vazia = porta
## destrancada desde o inicio, que e o comportamento anterior a esta mecanica.
@export var pacotes: Array[PacoteConfig] = []

@export_range(1, 10) var vidas_iniciais: int = 3

@export_range(0.0, 200.0, 1.0) var velocidade_cachorro: float = 45.0

## Replanejamento por intervalo, nao por quadro: o A* roda algumas vezes por
## segundo, e nao 60. E o que mantem a IA dentro do orcamento de quadro medido
## por AMOSTRA_DESEMPENHO (Eixo 7).
@export_range(0.0, 30.0, 0.1) var intervalo_replanejamento_s: float = 1.0

## Distancia maxima em pixels na qual o cachorro pode enxergar o jogador em
## linha reta (RayCast2D contra o labirinto -- ver Cachorro.tem_linha_de_visao).
## No Marco 1 o cachorro persegue a posicao real do jogador o tempo todo (nao
## ha Diretor ainda); este raio so controla quando CACHORRO_DETECTOU/
## CACHORRO_PERDEU disparam, preparando o terreno para o Marco 2, quando a
## linha de visao passa a decidir entre perseguir a posicao real ou o alvo do
## Diretor (docs/decisoes/0007-marco1-cachorro-e-desafios.md).
@export_range(8.0, 400.0, 1.0) var alcance_deteccao_cachorro: float = 90.0

@export_multiline var briefing_pedagogico: String = ""

## Mostra ao jogador o comando que para cada vigia (legenda na HUD e lista no
## terminal ao entrar). Decisao do professor, por fase: numa fase de
## APRESENTACAO o comando e o conteudo sendo ensinado e precisa estar a vista;
## numa fase de AVALIACAO, mostrar entregaria a resposta.
@export var mostrar_comandos: bool = false

## Exemplo FIXO usado pelo painel de demonstração (CIFRA_DEMONSTRADA, Marco 2)
## -- de propósito independente do desafio corrente: o painel ensina o
## MECANISMO da cifra, não é um jeito de espiar a chave que resolve o desafio
## ativo (isso já existe, e custa pontos: o verbo "dica"). Vazio nesta fase
## (Marco 1) porque o painel não é usado até o Marco 2 -- ver ADR 0008.
@export var texto_exemplo_demonstracao: String = ""
@export var chave_exemplo_demonstracao: String = ""

@export_group("Economia de erro")
## Duracao da protecao apos um comando correto. Limitada de proposito: o jogador
## tem que reaplicar a cifra, e e isso que produz repeticao com intencao.
@export_range(0.0, 120.0, 0.5) var duracao_cifra_s: float = 12.0

## Depois de uma captura o jogador volta ao inicio e fica este tempo sem poder
## ser pego de novo (pisca na tela). Sem isso, um cachorro perto da entrada
## capturava de novo no mesmo instante -- a "morte em sequencia" que nao ensina
## nada e so frustra.
@export_range(0.0, 10.0, 0.5) var invulnerabilidade_apos_captura_s: float = 2.0
@export_range(0, 1000, 5) var penalidade_captura: int = 50
@export_range(1, 60, 1) var faixa_chave_minima: int = 1
@export_range(1, 60, 1) var faixa_chave_maxima: int = 26

@export_group("Diretor de IA")
## Marco 2. Ficam aqui, e nao em constantes do diretor.gd, porque a secao 7 do
## CLAUDE.md exige que todo parametro do Diretor seja ajustavel no Inspector.
@export_range(0.0, 5.0, 0.05) var peso_pista_comando_errado: float = 1.0
@export_range(0.0, 5.0, 0.05) var peso_pista_movimento: float = 0.25
## Reforço de crença na região onde a captura acabou de acontecer -- posição
## real e conhecida no instante da captura (é um evento físico, não uma
## suposição), então é uma pista muito mais forte que um comando errado.
@export_range(0.0, 5.0, 0.05) var peso_pista_captura: float = 2.0
@export_range(0.0, 1.0, 0.01) var decaimento_crenca_por_s: float = 0.1
@export_range(0.0, 30.0, 0.1) var intervalo_decisao_diretor_s: float = 2.0


## Lista de problemas que impedem a fase de rodar. fase_base.gd chama isto no
## _ready e falha com mensagem clara -- criterio de aceite do Marco 0: a cena pai
## nao pode ser jogada sozinha nem com configuracao incoerente.
func problemas() -> PackedStringArray:
	var lista := PackedStringArray()

	if numero < 1 or numero > 4:
		lista.append("numero %d fora de 1..4 (constraint do banco)" % numero)

	if titulo.strip_edges().is_empty():
		lista.append("titulo vazio")

	if verbos_permitidos.is_empty():
		lista.append("verbos_permitidos vazio: o terminal recusaria qualquer comando")

	# Desafio de terminal so e obrigatorio quando ALGUM cachorro depende dele
	# para ser enganado. Uma fase de autoria em que todos os cachorros bloqueiam
	# por comando livre (ou so perseguem) e valida sem nenhum desafio -- exigir
	# um ali seria pedir dado que a mecanica dela nao usa.
	if desafios.is_empty() and _algum_cachorro_exige_cifra():
		lista.append("nenhum desafio configurado, mas ha cachorro que so e enganado por cifra")

	if faixa_chave_minima > faixa_chave_maxima:
		lista.append("faixa de chave invertida (%d > %d)"
			% [faixa_chave_minima, faixa_chave_maxima])

	var identificadores: Dictionary = {}
	for i: int in desafios.size():
		var desafio: DesafioConfig = desafios[i]
		if desafio == null:
			lista.append("desafio %d nulo" % i)
			continue
		for problema: String in desafio.problemas():
			lista.append(problema)
		if identificadores.has(desafio.identificador):
			lista.append("identificador de desafio repetido: %s" % desafio.identificador)
		identificadores[desafio.identificador] = true
		if not verbos_permitidos.has(desafio.verbo_esperado):
			lista.append("desafio '%s' espera o verbo '%s', que nao esta em verbos_permitidos"
				% [desafio.identificador, desafio.verbo_esperado])

	var identificadores_de_cachorro: Dictionary = {}
	var algoritmos_disponiveis: PackedStringArray = algoritmos_dos_desafios()
	for i: int in cachorros.size():
		var cachorro: CachorroConfig = cachorros[i]
		if cachorro == null:
			lista.append("cachorro %d nulo" % i)
			continue
		for problema: String in cachorro.problemas():
			lista.append(problema)
		if identificadores_de_cachorro.has(cachorro.identificador):
			lista.append("identificador de cachorro repetido: %s" % cachorro.identificador)
		identificadores_de_cachorro[cachorro.identificador] = true

		# A regra de justica da mecanica de cores: so entra na fase o cachorro
		# cuja cifra o jogador consegue produzir AQUI. Um cachorro azul numa
		# fase que so ensina Cesar seria uma captura inevitavel -- e um erro de
		# configuracao, nao de habilidade, entao ele reprova a fase inteira em
		# vez de virar frustracao no laboratorio da escola.
		# So o cachorro do modo CIFRA passa pela regra de justica: quem bloqueia
		# por comando traz o comando consigo (nao ha como ser inalcancavel), e
		# quem so persegue nunca foi feito para ser enganado.
		if not cachorro.bloqueia_por_cifra():
			continue

		if not algoritmos_disponiveis.has(cachorro.algoritmo_exigido):
			lista.append(("cachorro '%s' exige %s, mas nenhum desafio desta fase produz "
				+ "essa cifra (disponiveis: %s)") % [
					cachorro.identificador, cachorro.algoritmo_exigido,
					", ".join(algoritmos_disponiveis)])

	if mapa != null:
		for problema: String in mapa.problemas(self):
			lista.append("mapa: %s" % problema)

	var identificadores_de_pacote: Dictionary = {}
	for i: int in pacotes.size():
		var pacote: PacoteConfig = pacotes[i]
		if pacote == null:
			lista.append("pacote %d nulo" % i)
			continue
		for problema: String in pacote.problemas():
			lista.append(problema)
		if identificadores_de_pacote.has(pacote.identificador):
			lista.append("identificador de pacote repetido: %s" % pacote.identificador)
		identificadores_de_pacote[pacote.identificador] = true

	return lista


## Ha cachorro cuja unica defesa e a cifra certa? Cachorro que bloqueia por
## comando livre nao conta, e cachorro que so persegue tambem nao.
func _algum_cachorro_exige_cifra() -> bool:
	for cachorro: CachorroConfig in cachorros:
		if cachorro != null and cachorro.bloqueia_por_cifra():
			return true
	# Fase sem cachorro nenhum: o desafio de terminal continua sendo o conteudo
	# dela, entao a exigencia antiga vale.
	return cachorros.is_empty()


## Algoritmos que o jogador consegue ativar nesta fase, um por desafio (cada
## desafio herda o algoritmo da fase quando nao declara o proprio).
func algoritmos_dos_desafios() -> PackedStringArray:
	var lista := PackedStringArray()
	for desafio: DesafioConfig in desafios:
		if desafio == null:
			continue
		var algoritmo_do_desafio: String = desafio.algoritmo_efetivo(algoritmo)
		if not lista.has(algoritmo_do_desafio):
			lista.append(algoritmo_do_desafio)
	return lista


## Garante que a fase tenha identidade antes de gerar telemetria.
##
## Um id gerado em runtime (recurso antigo, sem id gravado) vale para a sessao,
## mas NAO e estavel entre execucoes -- o aviso existe para isso nao passar
## despercebido numa coleta de verdade, onde a analise precisa parear as sessoes
## de uma mesma fase. Rodar o gerador da fase grava o id de vez.
func garantir_id_fase() -> String:
	if Identificador.e_uuid(id_fase):
		return id_fase

	id_fase = Identificador.uuid_v4()
	Registro.aviso("FaseConfig", ("fase '%s' sem id_fase gravado; gerado um temporario (%s). "
		+ "Rode tools/gerar_fase_0N.gd para grava-lo no recurso -- sem isso, cada execucao "
		+ "usa um id diferente e a analise nao consegue juntar as sessoes desta fase.")
		% [titulo, id_fase])
	return id_fase


func valida() -> bool:
	return problemas().is_empty()


func desafio_por_identificador(identificador: String) -> DesafioConfig:
	for desafio: DesafioConfig in desafios:
		if desafio != null and desafio.identificador == identificador:
			return desafio
	return null
