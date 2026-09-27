class_name ResumoTelemetria
extends RefCounted

## Agrega os registros de telemetria nos numeros que o Dashboard mostra
## (Figura 7 da monografia): acertos x erros, tempo de resolucao e, por fase,
## quantas partidas foram jogadas e como terminaram.
##
## Logica pura, sem no nenhum -- e o que torna a agregacao testavel sem abrir a
## tela, do mesmo jeito que DemonstracaoCifra e testavel sem abrir o painel da
## cifra. A tela so desenha o que este arquivo calcula.
##
## As fases sao agrupadas por `id_fase`, nunca pelo numero: numa ferramenta em
## que o professor cria fases livremente, o numero nao identifica nada (duas
## fases podem nascer "5"). O titulo entra so como rotulo legivel. Jogar de
## novo a MESMA fase (mesmo id_fase) soma na mesma linha -- e isso que faz o
## painel de uma fase mudar a cada partida.

const PARTIDA_CONCLUIDA: String = "CONCLUIDA"
const PARTIDA_ABANDONADA: String = "ABANDONADA"
## FASE_INICIADA sem fim registrado: o jogo fechou no meio, ou a partida ainda
## esta em curso. Nao entra na taxa de conclusao nem no tempo medio.
const PARTIDA_SEM_FIM: String = "SEM_FIM"


## Uma partida = de um FASE_INICIADA ate o FASE_CONCLUIDA/ABANDONADA seguinte
## da mesma sessao.
class Partida:
	extends RefCounted
	var id_sessao: String = ""
	var iniciada_em: String = ""
	var resultado: String = PARTIDA_SEM_FIM
	var duracao_ms: int = -1
	var pontuacao: int = 0
	var capturas: int = 0

	func para_dicionario() -> Dictionary:
		return {
			"id_sessao": id_sessao,
			"iniciada_em": iniciada_em,
			"resultado": resultado,
			"duracao_s": float(duracao_ms) / 1000.0 if duracao_ms >= 0 else null,
			"pontuacao": pontuacao,
			"capturas": capturas,
		}


class ResumoDeFase:
	extends RefCounted
	var id_fase: String = ""
	var titulo: String = ""
	var acertos: int = 0
	var erros: int = 0
	var soma_tempo_ms: int = 0
	var dicas: int = 0
	var capturas: int = 0
	var ultima_vez: String = ""
	var partidas: Array[Partida] = []

	func tentativas() -> int:
		return acertos + erros

	func tempo_medio_ms() -> float:
		return float(soma_tempo_ms) / float(tentativas()) if tentativas() > 0 else 0.0

	func taxa_de_acerto() -> float:
		return float(acertos) / float(tentativas()) if tentativas() > 0 else 0.0

	func partidas_com(resultado: String) -> int:
		var total: int = 0
		for partida: Partida in partidas:
			if partida.resultado == resultado:
				total += 1
		return total

	func concluidas() -> int:
		return partidas_com(PARTIDA_CONCLUIDA)

	func abandonadas() -> int:
		return partidas_com(PARTIDA_ABANDONADA)

	## Sobre as partidas que TERMINARAM: uma partida em curso nao e fracasso.
	func taxa_de_conclusao() -> float:
		var terminadas: int = concluidas() + abandonadas()
		return float(concluidas()) / float(terminadas) if terminadas > 0 else 0.0

	func tempo_medio_de_conclusao_ms() -> float:
		var soma: int = 0
		var n: int = 0
		for partida: Partida in partidas:
			if partida.resultado == PARTIDA_CONCLUIDA and partida.duracao_ms >= 0:
				soma += partida.duracao_ms
				n += 1
		return float(soma) / float(n) if n > 0 else 0.0

	func pontuacao_media() -> float:
		var n: int = concluidas()
		if n == 0:
			return 0.0
		var soma: int = 0
		for partida: Partida in partidas:
			if partida.resultado == PARTIDA_CONCLUIDA:
				soma += partida.pontuacao
		return float(soma) / float(n)

	func melhor_pontuacao() -> int:
		var melhor: int = 0
		for partida: Partida in partidas:
			if partida.resultado == PARTIDA_CONCLUIDA:
				melhor = maxi(melhor, partida.pontuacao)
		return melhor

	## Como a fase aparece na tela: o titulo quando ha um, senao o id abreviado.
	## Nunca "Nivel 1/2" fixo -- as fases sao livres.
	func rotulo() -> String:
		if not titulo.strip_edges().is_empty():
			return titulo
		if not id_fase.is_empty():
			return "fase %s" % id_fase.substr(0, 8)
		return "(sem fase)"

	func para_dicionario() -> Dictionary:
		var lista: Array[Dictionary] = []
		for partida: Partida in partidas:
			lista.append(partida.para_dicionario())
		return {
			"id_fase": id_fase,
			"titulo_fase": titulo,
			"partidas": partidas.size(),
			"concluidas": concluidas(),
			"abandonadas": abandonadas(),
			"taxa_de_conclusao": taxa_de_conclusao(),
			"tempo_medio_de_conclusao_s": tempo_medio_de_conclusao_ms() / 1000.0,
			"pontuacao_media": pontuacao_media(),
			"melhor_pontuacao": melhor_pontuacao(),
			"capturas": capturas,
			"dicas": dicas,
			"tentativas": tentativas(),
			"acertos": acertos,
			"erros": erros,
			"taxa_de_acerto": taxa_de_acerto(),
			"tempo_medio_ms": tempo_medio_ms(),
			"ultima_vez": ultima_vez,
			"historico_de_partidas": lista,
		}


var acertos: int = 0
var erros: int = 0
var sessoes: int = 0
var por_fase: Array[ResumoDeFase] = []
## Fases que entraram no calculo. Vazio = todas.
var filtro: PackedStringArray = PackedStringArray()


func tentativas() -> int:
	return acertos + erros


func taxa_de_acerto() -> float:
	return float(acertos) / float(tentativas()) if tentativas() > 0 else 0.0


func vazio() -> bool:
	return tentativas() == 0 and sessoes == 0 and total_de_partidas() == 0


func total_de_partidas() -> int:
	var total: int = 0
	for fase: ResumoDeFase in por_fase:
		total += fase.partidas.size()
	return total


func total_concluidas() -> int:
	var total: int = 0
	for fase: ResumoDeFase in por_fase:
		total += fase.concluidas()
	return total


func total_abandonadas() -> int:
	var total: int = 0
	for fase: ResumoDeFase in por_fase:
		total += fase.abandonadas()
	return total


func total_capturas() -> int:
	var total: int = 0
	for fase: ResumoDeFase in por_fase:
		total += fase.capturas
	return total


func total_dicas() -> int:
	var total: int = 0
	for fase: ResumoDeFase in por_fase:
		total += fase.dicas
	return total


func taxa_de_conclusao() -> float:
	var terminadas: int = total_concluidas() + total_abandonadas()
	return float(total_concluidas()) / float(terminadas) if terminadas > 0 else 0.0


## Media das partidas concluidas de todas as fases do resumo (ponderada por
## partida, nao media de medias: uma fase jogada uma vez nao pesa igual a uma
## jogada vinte).
func tempo_medio_de_conclusao_ms() -> float:
	var soma: float = 0.0
	var n: int = 0
	for fase: ResumoDeFase in por_fase:
		for partida: Partida in fase.partidas:
			if partida.resultado == PARTIDA_CONCLUIDA and partida.duracao_ms >= 0:
				soma += float(partida.duracao_ms)
				n += 1
	return soma / float(n) if n > 0 else 0.0


func tempo_medio_de_resposta_ms() -> float:
	var soma: int = 0
	for fase: ResumoDeFase in por_fase:
		soma += fase.soma_tempo_ms
	return float(soma) / float(tentativas()) if tentativas() > 0 else 0.0


func pontuacao_media() -> float:
	var soma: float = 0.0
	var n: int = 0
	for fase: ResumoDeFase in por_fase:
		for partida: Partida in fase.partidas:
			if partida.resultado == PARTIDA_CONCLUIDA:
				soma += float(partida.pontuacao)
				n += 1
	return soma / float(n) if n > 0 else 0.0


func capturas_por_partida() -> float:
	var n: int = total_de_partidas()
	return float(total_capturas()) / float(n) if n > 0 else 0.0


func fase(id_fase: String) -> ResumoDeFase:
	for item: ResumoDeFase in por_fase:
		if item.id_fase == id_fase:
			return item
	return null


## Troca o titulo gravado na telemetria pelo titulo ATUAL da fase (o professor
## pode ter renomeado no editor). O id_fase nao muda, entao a ligacao se mantem.
func aplicar_titulos(titulos_por_id: Dictionary) -> void:
	for item: ResumoDeFase in por_fase:
		var atual: String = _txt(titulos_por_id.get(item.id_fase))
		if not atual.is_empty():
			item.titulo = atual


# ---------------------------------------------------------------------------
# Leitura defensiva
#
# O registro local acumula linhas de TODAS as versoes do jogo que ja rodaram na
# maquina (fases fixas, antes do id_fase, arquivos cortados). Um campo com tipo
# inesperado -- "dados": null, "payload": [], "tempo_resposta_ms": "abc" --
# fazia o `as Dictionary` lancar erro e derrubar o painel inteiro. Aqui todo
# campo lido e dado NAO confiavel: tipo errado vira vazio, nunca erro.
# ---------------------------------------------------------------------------

static func _dic(valor: Variant) -> Dictionary:
	return valor as Dictionary if typeof(valor) == TYPE_DICTIONARY else {}


static func _txt(valor: Variant) -> String:
	if typeof(valor) == TYPE_STRING or typeof(valor) == TYPE_STRING_NAME:
		return String(valor)
	return ""


## JSON devolve numero como float; string numerica tambem e aceita.
static func _int(valor: Variant, padrao: int = 0) -> int:
	match typeof(valor):
		TYPE_INT:
			return valor as int
		TYPE_FLOAT:
			return int(valor as float)
		TYPE_STRING:
			var texto: String = valor as String
			return texto.to_int() if texto.is_valid_int() else padrao
	return padrao


## Monta o resumo a partir das linhas do JSONL, no formato
## {"tipo_registro": ..., "dados": {...}} -- o mesmo que iria para a rede.
##
## `filtro_id_fases` vazio = todas as fases; preenchido = so essas entram em
## TODOS os numeros (e o "media so das fases selecionadas" do painel).
static func de_registros(registros: Array[Dictionary],
		filtro_id_fases: PackedStringArray = PackedStringArray()) -> ResumoTelemetria:
	var resumo := ResumoTelemetria.new()
	resumo.filtro = filtro_id_fases
	var indice: Dictionary = {}          # chave da fase -> ResumoDeFase
	var sessoes_vistas: Dictionary = {}
	var partida_aberta: Dictionary = {}  # id_sessao -> Partida em curso

	for registro: Dictionary in registros:
		var tipo: String = _txt(registro.get("tipo_registro"))
		var dados: Dictionary = _dic(registro.get("dados"))
		if dados.is_empty() or (tipo != "tentativa" and tipo != "evento"):
			continue

		var id_fase: String = _txt(dados.get("id_fase"))
		var id_sessao: String = _txt(dados.get("id_sessao"))
		var sem_fase: bool = id_fase.is_empty() and _txt(dados.get("titulo_fase")).is_empty()

		if not filtro_id_fases.is_empty():
			if not filtro_id_fases.has(id_fase):
				continue
		# Sessao sem filtro conta mesmo sem fase (abriu o jogo e nao jogou);
		# com filtro, so as sessoes que tocaram as fases escolhidas.
		if not id_sessao.is_empty():
			sessoes_vistas[id_sessao] = true
		if sem_fase:
			continue

		var item: ResumoDeFase = _fase_do_registro(resumo, indice, dados)
		var quando: String = _txt(dados.get("ocorrido_em"))
		if quando > item.ultima_vez:
			item.ultima_vez = quando

		if tipo == "tentativa":
			_contar_tentativa(resumo, item, dados)
		else:
			_contar_evento(item, dados, partida_aberta)

	resumo.sessoes = sessoes_vistas.size()
	# Mais tentativas primeiro: a fase mais exercitada e a que mais interessa
	# olhar, e a ordem fica estavel entre aberturas da tela.
	resumo.por_fase.sort_custom(func(a: ResumoDeFase, b: ResumoDeFase) -> bool:
		if a.partidas.size() != b.partidas.size():
			return a.partidas.size() > b.partidas.size()
		return a.tentativas() > b.tentativas())
	return resumo


static func _fase_do_registro(resumo: ResumoTelemetria, indice: Dictionary,
		dados: Dictionary) -> ResumoDeFase:
	var chave: String = _txt(dados.get("id_fase"))
	if chave.is_empty():
		chave = _txt(dados.get("titulo_fase"))
	if not indice.has(chave):
		var nova := ResumoDeFase.new()
		nova.id_fase = _txt(dados.get("id_fase"))
		nova.titulo = _txt(dados.get("titulo_fase"))
		indice[chave] = nova
		resumo.por_fase.append(nova)
	var item: ResumoDeFase = indice[chave]
	if item.titulo.is_empty():
		item.titulo = _txt(dados.get("titulo_fase"))
	return item


static func _contar_tentativa(resumo: ResumoTelemetria, item: ResumoDeFase,
		dados: Dictionary) -> void:
	var resultado: String = _txt(dados.get("resultado"))
	# ABANDONO e TIMEOUT nao sao nem acerto nem erro de conhecimento: o
	# jogador nao respondeu. Conta-los como erro inflaria a taxa de erro
	# com desistencia, que e outro fenomeno.
	if resultado != CatalogoResultados.SUCESSO and not resultado.begins_with("ERRO_"):
		return
	if resultado == CatalogoResultados.SUCESSO:
		item.acertos += 1
		resumo.acertos += 1
	else:
		item.erros += 1
		resumo.erros += 1
	item.soma_tempo_ms += maxi(0, _int(dados.get("tempo_resposta_ms")))


static func _contar_evento(item: ResumoDeFase, dados: Dictionary,
		partida_aberta: Dictionary) -> void:
	var codigo: String = _txt(dados.get("tipo_evento"))
	var id_sessao: String = _txt(dados.get("id_sessao"))
	var payload: Dictionary = _dic(dados.get("payload"))

	match codigo:
		CatalogoEventos.FASE_INICIADA:
			var partida := Partida.new()
			partida.id_sessao = id_sessao
			partida.iniciada_em = _txt(dados.get("ocorrido_em"))
			item.partidas.append(partida)
			partida_aberta[id_sessao] = partida
		CatalogoEventos.FASE_CONCLUIDA, CatalogoEventos.FASE_ABANDONADA:
			var partida: Partida = partida_aberta.get(id_sessao, null) as Partida
			if partida == null:
				# Fim sem inicio (arquivo cortado no comeco): ainda e uma partida.
				partida = Partida.new()
				partida.id_sessao = id_sessao
				item.partidas.append(partida)
			partida.resultado = PARTIDA_CONCLUIDA \
				if codigo == CatalogoEventos.FASE_CONCLUIDA else PARTIDA_ABANDONADA
			partida.pontuacao = _int(payload.get("pontuacao"))
			partida.capturas = _int(payload.get("capturas"), partida.capturas)
			var inicio: int = Relogio.iso_para_unix_ms(partida.iniciada_em)
			var fim: int = Relogio.iso_para_unix_ms(_txt(dados.get("ocorrido_em")))
			if inicio >= 0 and fim >= inicio:
				partida.duracao_ms = fim - inicio
			partida_aberta.erase(id_sessao)
		CatalogoEventos.JOGADOR_CAPTURADO:
			item.capturas += 1
		CatalogoEventos.DICA_SOLICITADA:
			item.dicas += 1


## Le um arquivo JSONL (uma linha por registro). Linha corrompida e pulada, nao
## derruba a leitura: o arquivo pode ter sido cortado por um processo morto no
## meio da escrita, e o resto continua valendo.
static func ler_jsonl(caminho: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if caminho.is_empty() or not FileAccess.file_exists(caminho):
		return saida

	var arquivo: FileAccess = FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return saida

	while not arquivo.eof_reached():
		var linha: String = arquivo.get_line().strip_edges()
		if linha.is_empty():
			continue
		# JSON.new().parse() e nao JSON.parse_string(): a ultima linha cortada
		# por um processo morto e esperada, e parse_string grita push_error.
		var leitor := JSON.new()
		if leitor.parse(linha) == OK and typeof(leitor.data) == TYPE_DICTIONARY:
			saida.append(leitor.data as Dictionary)
	arquivo.close()
	return saida


## Os registros crus de uma fase so: e o que vai junto na exportacao de uma
## fase, para quem for analisar ter o dado bruto e nao so a media.
static func registros_da_fase(registros: Array[Dictionary], id_fase: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for registro: Dictionary in registros:
		var dados: Dictionary = _dic(registro.get("dados"))
		if _txt(dados.get("id_fase")) == id_fase:
			saida.append(registro)
	return saida


## O corpo do "Exportar JSON": os mesmos numeros da tela, em formato que abre em
## qualquer planilha ou script de analise.
func para_dicionario() -> Dictionary:
	var fases: Array[Dictionary] = []
	for item: ResumoDeFase in por_fase:
		fases.append(item.para_dicionario())

	return {
		"gerado_em": Relogio.agora_utc_iso(),
		"filtro_id_fases": Array(filtro),
		"sessoes": sessoes,
		"partidas": total_de_partidas(),
		"concluidas": total_concluidas(),
		"abandonadas": total_abandonadas(),
		"taxa_de_conclusao": taxa_de_conclusao(),
		"tempo_medio_de_conclusao_s": tempo_medio_de_conclusao_ms() / 1000.0,
		"pontuacao_media": pontuacao_media(),
		"capturas": total_capturas(),
		"capturas_por_partida": capturas_por_partida(),
		"dicas": total_dicas(),
		"tentativas": tentativas(),
		"acertos": acertos,
		"erros": erros,
		"taxa_de_acerto": taxa_de_acerto(),
		"tempo_medio_de_resposta_ms": tempo_medio_de_resposta_ms(),
		"por_fase": fases,
	}
