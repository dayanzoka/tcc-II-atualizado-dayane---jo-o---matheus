class_name ResolvedorComando
extends RefCounted

## Etapa SEMANTICA do pipeline do terminal: unico lugar do projeto que decide
## se um comando gramaticalmente correto faz sentido NESTA fase, para ESTE
## desafio. Recebe o resultado ja lexico+sintatico de AnalisadorComando e so
## roda se ele passou (resultado.passou_lexico_e_sintatico()) -- ERRO_LEXICO e
## ERRO_SINTATICO nunca chegam aqui, porque a etapa anterior ja e o veredito
## final para esses dois casos.
##
## Verificacoes, na ordem da secao 6 do CLAUDE.md (ERRO_SEMANTICO cobre "verbo
## nao permitido nesta fase" e "chave fora da faixa"; chave incorreta e a mesma
## familia -- "estrutura valida, significado invalido"):
##   1. verbo esta em FaseConfig.verbos_permitidos
##   2. "status" e "dica" nao precisam de desafio ativo alem da leitura; os
##      demais verbos exigem um desafio corrente
##   3. (cifrar/decifrar) o verbo bate com DesafioConfig.verbo_esperado
##   4. (cifrar/decifrar) ha um par_chave "chave"
##   5. (cifrar/decifrar) a chave e sintaticamente valida para o algoritmo
##      (Cifra.chave_sintaticamente_valida)
##   6. (cifrar/decifrar) a chave esta em [faixa_chave_minima, faixa_chave_maxima]
##   7. (cifrar/decifrar) a chave bate com DesafioConfig.chave_esperada
##
## Decisao registrada em docs/decisoes/0007-marco1-cachorro-e-desafios.md: uma
## chave sintaticamente valida e dentro da faixa, mas que nao resolve o
## desafio, tambem e ERRO_SEMANTICO (nao existe um codigo separado para "chave
## errada" na constraint do banco -- e a leitura mais proxima de "estrutura
## valida, significado invalido").

const _CODIGO_VERBO_NAO_PERMITIDO: String = "verbo_nao_permitido"
const _CODIGO_SEM_DESAFIO_ATIVO: String = "sem_desafio_ativo"
const _CODIGO_VERBO_NAO_ESPERADO: String = "verbo_nao_esperado_pelo_desafio"
const _CODIGO_CHAVE_AUSENTE: String = "chave_ausente"
const _CODIGO_CHAVE_INVALIDA: String = "chave_invalida"
const _CODIGO_CHAVE_FORA_DA_FAIXA: String = "chave_fora_da_faixa"
const _CODIGO_CHAVE_INCORRETA: String = "chave_incorreta"
const _CODIGO_ALGORITMO_NAO_SUPORTADO: String = "algoritmo_nao_suportado_nesta_fase"
const _CODIGO_ARGUMENTO_AUSENTE: String = "argumento_ausente"
const _CODIGO_DIGEST_INCORRETO: String = "digest_incorreto"


## desafio pode ser null (todos os desafios da fase ja foram resolvidos):
## "status" continua funcionando, os demais verbos que dependem de desafio
## caem em _CODIGO_SEM_DESAFIO_ATIVO.
static func resolver(
		configuracao: FaseConfig,
		desafio: DesafioConfig,
		numero_tentativa: int,
		resultado_comando: ResultadoComando) -> VeredictoComando:

	assert(resultado_comando.passou_lexico_e_sintatico(),
		"ResolvedorComando so roda apos lexico e sintatico passarem")

	var ast: NoAst = resultado_comando.ast
	var verbo: String = ast.verbo

	if not configuracao.verbos_permitidos.has(verbo):
		return VeredictoComando.semantico(_CODIGO_VERBO_NAO_PERMITIDO,
			"'%s' nao e um comando desta fase." % verbo)

	match verbo:
		"status":
			return _resolver_status(configuracao, desafio)
		"dica":
			return _resolver_dica(desafio)
		"cifrar", "decifrar":
			return _resolver_cifra(configuracao, desafio, numero_tentativa, ast)
		"hash":
			return _resolver_hash(ast)
		"verificar":
			return _resolver_verificar(configuracao, desafio, numero_tentativa, ast)

	return VeredictoComando.semantico(_CODIGO_VERBO_NAO_PERMITIDO, "comando desconhecido.")


static func _resolver_status(configuracao: FaseConfig, desafio: DesafioConfig) -> VeredictoComando:
	var enunciado: String = desafio.enunciado if desafio != null else "todos os desafios resolvidos."
	return VeredictoComando.sucesso("fase %d -- %s\n%s"
		% [configuracao.numero, configuracao.titulo, enunciado])


static func _resolver_dica(desafio: DesafioConfig) -> VeredictoComando:
	if desafio == null:
		return VeredictoComando.semantico(_CODIGO_SEM_DESAFIO_ATIVO,
			"nao ha desafio ativo para pedir dica.")

	var veredicto: VeredictoComando = VeredictoComando.sucesso(desafio.dica)
	veredicto.dica_solicitada = true
	veredicto.delta_pontos = -desafio.custo_da_dica
	return veredicto


static func _resolver_cifra(
		configuracao: FaseConfig, desafio: DesafioConfig, numero_tentativa: int, ast: NoAst) -> VeredictoComando:
	if desafio == null:
		return VeredictoComando.semantico(_CODIGO_SEM_DESAFIO_ATIVO,
			"nao ha desafio ativo para %s." % ast.verbo)

	if ast.verbo != desafio.verbo_esperado:
		return VeredictoComando.semantico(_CODIGO_VERBO_NAO_ESPERADO,
			"este desafio espera '%s', nao '%s'." % [desafio.verbo_esperado, ast.verbo])

	if not ast.tem_par_chave("chave"):
		return VeredictoComando.semantico(_CODIGO_CHAVE_AUSENTE,
			"faltou 'chave=<valor>'.")

	# O algoritmo vem do DESAFIO (que por padrao herda o da fase), e nao da fase
	# direto: uma fase pode oferecer mais de uma cifra para o jogador ter como
	# se proteger de cachorros de cores diferentes -- ver DesafioConfig.algoritmo.
	var algoritmo: String = desafio.algoritmo_efetivo(configuracao.algoritmo)

	var cifra: Cifra = FabricaCifra.para_algoritmo(algoritmo)
	if cifra == null:
		return VeredictoComando.semantico(_CODIGO_ALGORITMO_NAO_SUPORTADO,
			"algoritmo '%s' nao esta disponivel nesta fase." % algoritmo)

	var chave: String = ast.par_chave("chave")
	if not cifra.chave_sintaticamente_valida(chave):
		return VeredictoComando.semantico(_CODIGO_CHAVE_INVALIDA,
			"'%s' nao e uma chave valida para %s." % [chave, algoritmo])

	if not cifra.dentro_da_faixa(chave, configuracao.faixa_chave_minima, configuracao.faixa_chave_maxima):
		return VeredictoComando.semantico(_CODIGO_CHAVE_FORA_DA_FAIXA,
			"a chave precisa estar entre %d e %d." % [
				configuracao.faixa_chave_minima, configuracao.faixa_chave_maxima])

	if not _chaves_equivalentes(chave, desafio.chave_esperada):
		return VeredictoComando.semantico(_CODIGO_CHAVE_INCORRETA,
			"essa chave nao protege o pacote deste desafio.")

	var veredicto: VeredictoComando = VeredictoComando.sucesso(
		"pacote protegido em %s. quem le %s nao reconhece mais o conteudo -- os outros interceptadores, sim."
		% [LegendaCores.nome(algoritmo), LegendaCores.nome(algoritmo)])
	veredicto.resolveu_desafio = true
	veredicto.duracao_protecao_s = configuracao.duracao_cifra_s
	veredicto.algoritmo_protecao = algoritmo
	veredicto.delta_pontos = desafio.pontos_acerto_de_primeira if numero_tentativa <= 1 \
		else desafio.pontos_acerto
	return veredicto


static func _chaves_equivalentes(chave_digitada: String, chave_esperada: String) -> bool:
	if chave_digitada.is_valid_int() and chave_esperada.is_valid_int():
		return int(chave_digitada) == int(chave_esperada)
	return chave_digitada == chave_esperada


## "hash <palavra>" e um utilitario, nao depende de desafio (como "status") --
## e a ferramenta que o jogador usa para CALCULAR o digest antes de decidir o
## que digitar em "verificar". Calcula de verdade (scripts/cripto/sha256.gd
## sobre HashingContext), nao mostra um valor pre-fabricado: a licao da fase 3
## e que o jogador pode conferir o hash de qualquer coisa a qualquer momento,
## e o resultado e sempre reproduzivel.
static func _resolver_hash(ast: NoAst) -> VeredictoComando:
	var soltos: Array[String] = ast.argumentos_soltos()
	if soltos.is_empty():
		return VeredictoComando.semantico(_CODIGO_ARGUMENTO_AUSENTE, "digite 'hash <palavra>'.")

	var palavra: String = soltos[0]
	return VeredictoComando.sucesso("sha256(%s) = %s" % [palavra, Sha256.digest_hex(palavra)])


## "verificar <palavra> <prefixo_hash>" resolve o desafio da fase 3: o pacote
## chega com um digest anexado, e o jogador precisa confirmar que bate antes
## de entregar. O primeiro argumento (<palavra>) e decorativo, do mesmo jeito
## que "pacote" e decorativo em "cifrar pacote chave=3" -- nenhum dos dois
## verbos de cifra valida esse argumento contra o desafio, entao verificar nao
## seria consistente se validasse.
##
## DesafioConfig.resposta_esperada guarda o prefixo correto (nao recalculado
## na hora): o mesmo padrao de comparacao fixa que chave_esperada usa para
## Cesar/Vigenere, para o resolvedor nao precisar saber de hash nenhum alem
## de chamar Sha256 no verbo "hash". Quem autora o desafio e responsavel por
## manter resposta_esperada = prefixo real de sha256(texto_claro) -- e o
## tools/gerar_fase_03.gd faz isso calculando de verdade, nao inventando.
##
## SUCESSO ativa "protecao" do mesmo jeito que cifrar/decifrar (FaseConfig.
## duracao_cifra_s) -- reinterpretada aqui como "pacote com integridade
## confirmada, liberado para entrega" em vez de "texto ilegivel para o
## cachorro". A mecanica de fase_base.gd (captura so acontece sem protecao
## ativa) nao muda uma linha; so o SIGNIFICADO pedagogico da protecao muda
## entre fases, o que e exatamente o ponto do requisito de "baixo esforco de
## codificacao" (ver docs/decisoes/0009).
static func _resolver_verificar(
		configuracao: FaseConfig, desafio: DesafioConfig, numero_tentativa: int, ast: NoAst) -> VeredictoComando:
	if desafio == null:
		return VeredictoComando.semantico(_CODIGO_SEM_DESAFIO_ATIVO, "nao ha pacote ativo para verificar.")

	if ast.verbo != desafio.verbo_esperado:
		return VeredictoComando.semantico(_CODIGO_VERBO_NAO_ESPERADO,
			"este desafio espera '%s', nao 'verificar'." % desafio.verbo_esperado)

	var soltos: Array[String] = ast.argumentos_soltos()
	if soltos.size() < 2:
		return VeredictoComando.semantico(_CODIGO_ARGUMENTO_AUSENTE,
			"digite 'verificar <palavra> <prefixo_hash>'.")

	var prefixo_digitado: String = soltos[1]
	if prefixo_digitado != desafio.resposta_esperada:
		return VeredictoComando.semantico(_CODIGO_DIGEST_INCORRETO,
			"esse prefixo nao bate com o digest do pacote. o conteudo pode ter sido adulterado.")

	var veredicto: VeredictoComando = VeredictoComando.sucesso(
		"integridade confirmada. o pacote pode ser entregue.")
	veredicto.resolveu_desafio = true
	veredicto.duracao_protecao_s = configuracao.duracao_cifra_s
	veredicto.algoritmo_protecao = desafio.algoritmo_efetivo(configuracao.algoritmo)
	veredicto.delta_pontos = desafio.pontos_acerto_de_primeira if numero_tentativa <= 1 \
		else desafio.pontos_acerto
	return veredicto
