extends CasoDeTeste

## Etapa semantica isolada: ResultadoComando entra ja lexico+sintaticamente
## valido (via AnalisadorComando, como no pipeline real), e este arquivo cobre
## as decisoes que so o FaseConfig e o desafio corrente sabem tomar.


func _configuracao() -> FaseConfig:
	var config := FaseConfig.new()
	config.numero = 1
	config.titulo = "labirinto de Cesar"
	config.algoritmo = "CESAR"
	config.verbos_permitidos = ["cifrar", "decifrar", "dica", "status"]
	config.faixa_chave_minima = 1
	config.faixa_chave_maxima = 25
	config.duracao_cifra_s = 12.0
	return config


func _desafio() -> DesafioConfig:
	var desafio := DesafioConfig.new()
	desafio.identificador = "cesar-01"
	desafio.enunciado = "proteja o pacote antes do cachorro chegar."
	desafio.texto_claro = "pacote"
	desafio.chave_esperada = "3"
	desafio.verbo_esperado = "cifrar"
	desafio.dica = "some 3 letras de cada uma."
	desafio.pontos_acerto = 100
	desafio.pontos_acerto_de_primeira = 150
	desafio.custo_da_dica = 25
	return desafio


func _configuracao_vigenere() -> FaseConfig:
	var config := FaseConfig.new()
	config.numero = 2
	config.titulo = "labirinto de Vigenere"
	config.algoritmo = "VIGENERE"
	config.verbos_permitidos = ["cifrar", "decifrar", "dica", "status"]
	config.faixa_chave_minima = 3
	config.faixa_chave_maxima = 8
	config.duracao_cifra_s = 12.0
	return config


func _desafio_vigenere() -> DesafioConfig:
	var desafio := DesafioConfig.new()
	desafio.identificador = "vigenere-01"
	desafio.enunciado = "proteja o pacote com uma chave alfabetica."
	desafio.texto_claro = "pacote"
	desafio.chave_esperada = "gato"
	desafio.verbo_esperado = "cifrar"
	desafio.dica = "a chave e um bicho de estimacao."
	desafio.pontos_acerto = 100
	desafio.pontos_acerto_de_primeira = 150
	desafio.custo_da_dica = 25
	return desafio


func _resultado(texto: String) -> ResultadoComando:
	var resultado: ResultadoComando = AnalisadorComando.analisar(texto)
	assert(resultado.passou_lexico_e_sintatico(), "teste mal escrito: '%s' deveria ser valido" % texto)
	return resultado


func teste_verbo_fora_de_verbos_permitidos() -> void:
	var config: FaseConfig = _configuracao()
	config.verbos_permitidos = ["cifrar"]  # decifrar nao permitido nesta fase
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		config, _desafio(), 1, _resultado("decifrar pacote chave=3"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.ERRO_SEMANTICO, "verbo fora da fase")
	afirmar_igual(veredicto.codigo_erro, "verbo_nao_permitido", "codigo fixo")


func teste_status_sempre_sucesso_mesmo_sem_desafio() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), null, 1, _resultado("status"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.SUCESSO, "status nao depende de desafio")


func teste_dica_sem_desafio_ativo() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), null, 1, _resultado("dica"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.ERRO_SEMANTICO, "sem desafio para dar dica")
	afirmar_igual(veredicto.codigo_erro, "sem_desafio_ativo", "codigo fixo")


func teste_dica_custa_pontos_e_nao_resolve_o_desafio() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), _desafio(), 1, _resultado("dica"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.SUCESSO, "dica e um comando valido")
	afirmar_verdadeiro(veredicto.dica_solicitada, "marca DICA_SOLICITADA para o chamador emitir")
	afirmar_igual(veredicto.delta_pontos, -25, "custa custo_da_dica, nao vida")
	afirmar_falso(veredicto.resolveu_desafio, "dica nao resolve o desafio")


func teste_cifrar_sem_desafio_ativo() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), null, 1, _resultado("cifrar pacote chave=3"))
	afirmar_igual(veredicto.codigo_erro, "sem_desafio_ativo", "nao ha o que proteger")


func teste_verbo_nao_esperado_pelo_desafio() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), _desafio(), 1, _resultado("decifrar pacote chave=3"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.ERRO_SEMANTICO,
		"o desafio espera 'cifrar', nao 'decifrar'")
	afirmar_igual(veredicto.codigo_erro, "verbo_nao_esperado_pelo_desafio", "codigo fixo")


func teste_chave_ausente() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), _desafio(), 1, _resultado("cifrar pacote"))
	afirmar_igual(veredicto.codigo_erro, "chave_ausente", "cifrar exige par_chave")


func teste_chave_sintaticamente_invalida() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), _desafio(), 1, _resultado("cifrar pacote chave=gato"))
	afirmar_igual(veredicto.codigo_erro, "chave_invalida", "Cesar exige chave inteira")


func teste_chave_fora_da_faixa_da_fase() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), _desafio(), 1, _resultado("cifrar pacote chave=99"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.ERRO_SEMANTICO, "99 esta fora de 1..25")
	afirmar_igual(veredicto.codigo_erro, "chave_fora_da_faixa", "codigo fixo")


func teste_chave_dentro_da_faixa_mas_incorreta() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), _desafio(), 1, _resultado("cifrar pacote chave=7"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.ERRO_SEMANTICO,
		"7 esta na faixa mas nao resolve o desafio (esperado: 3)")
	afirmar_igual(veredicto.codigo_erro, "chave_incorreta", "codigo fixo")


func teste_sucesso_completo_ativa_protecao_e_pontua_de_primeira() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), _desafio(), 1, _resultado("cifrar pacote chave=3"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.SUCESSO, "chave correta")
	afirmar_verdadeiro(veredicto.resolveu_desafio, "desafio resolvido")
	afirmar_igual(veredicto.duracao_protecao_s, 12.0, "duracao vem de FaseConfig.duracao_cifra_s")
	afirmar_igual(veredicto.delta_pontos, 150, "bonus de primeira tentativa")


func teste_sucesso_em_segunda_tentativa_nao_ganha_bonus() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao(), _desafio(), 2, _resultado("cifrar pacote chave=3"))
	afirmar_igual(veredicto.delta_pontos, 100, "pontuacao normal, sem bonus, na segunda tentativa")


# ---------------------------------------------------------------------------
# SHA-256 (Marco 3): "hash" calcula (utilitario, sem desafio), "verificar"
# resolve o desafio -- mesmo pipeline, resolvedor generico de novo.
# ---------------------------------------------------------------------------

func _configuracao_sha256() -> FaseConfig:
	var config := FaseConfig.new()
	config.numero = 3
	config.titulo = "o labirinto de SHA-256"
	config.algoritmo = "SHA256"
	config.verbos_permitidos = ["hash", "verificar", "dica", "status"]
	config.duracao_cifra_s = 12.0
	return config


func _desafio_sha256() -> DesafioConfig:
	var desafio := DesafioConfig.new()
	desafio.identificador = "sha256-01"
	desafio.enunciado = "confira a integridade do pacote 'pacote' antes de entregar."
	desafio.texto_claro = "pacote"
	desafio.chave_esperada = ""  # hash nao tem chave
	desafio.resposta_esperada = Sha256.digest_hex("pacote").substr(0, 8)
	desafio.verbo_esperado = "verificar"
	desafio.dica = "use 'hash pacote' para calcular o digest voce mesmo."
	desafio.pontos_acerto = 100
	desafio.pontos_acerto_de_primeira = 150
	desafio.custo_da_dica = 25
	return desafio


func teste_hash_calcula_o_digest_real_sem_precisar_de_desafio() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao_sha256(), null, 1, _resultado("hash pacote"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.SUCESSO, "hash e um utilitario, nao um desafio")
	afirmar_contem(veredicto.texto_para_terminal, Sha256.digest_hex("pacote"),
		"mostra o digest de verdade, calculado na hora")


func teste_hash_sem_argumento_e_erro_semantico() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao_sha256(), null, 1, _resultado("hash"))
	afirmar_igual(veredicto.codigo_erro, "argumento_ausente", "'hash' sozinho nao tem o que calcular")


func teste_verificar_sem_desafio_ativo() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao_sha256(), null, 1, _resultado("verificar pacote a1b2c3d4"))
	afirmar_igual(veredicto.codigo_erro, "sem_desafio_ativo", "nao ha pacote para conferir")


func teste_verificar_prefixo_incorreto() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao_sha256(), _desafio_sha256(), 1, _resultado("verificar pacote abcdef00"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.ERRO_SEMANTICO,
		"prefixo errado -- pacote pode ter sido adulterado")
	afirmar_igual(veredicto.codigo_erro, "digest_incorreto", "codigo fixo")


func teste_verificar_prefixo_correto_confirma_integridade() -> void:
	var prefixo_correto: String = Sha256.digest_hex("pacote").substr(0, 8)
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao_sha256(), _desafio_sha256(), 1,
		_resultado("verificar pacote %s" % prefixo_correto))
	afirmar_igual(veredicto.resultado, CatalogoResultados.SUCESSO, "prefixo bate com o digest real")
	afirmar_verdadeiro(veredicto.resolveu_desafio, "integridade confirmada resolve o desafio")
	afirmar_igual(veredicto.duracao_protecao_s, 12.0,
		"verificar tambem libera o pacote para entrega, como cifrar/decifrar liberam protecao")


# ---------------------------------------------------------------------------
# Vigenere (Marco 2) -- o MESMO resolvedor, sem alterar uma linha alem do
# dispatch de algoritmo (ResolvedorComando._cifra_para_algoritmo). Se isto nao
# fosse verdade, a generalizacao do Marco 1 teria falhado.
# ---------------------------------------------------------------------------

func teste_vigenere_chave_numerica_e_sintaticamente_invalida() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao_vigenere(), _desafio_vigenere(), 1, _resultado("cifrar pacote chave=3"))
	afirmar_igual(veredicto.codigo_erro, "chave_invalida", "Vigenere exige chave alfabetica, nao numerica")


func teste_vigenere_faixa_e_comprimento_nao_valor() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao_vigenere(), _desafio_vigenere(), 1, _resultado("cifrar pacote chave=ab"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.ERRO_SEMANTICO, "'ab' tem 2 letras, faixa e 3..8")
	afirmar_igual(veredicto.codigo_erro, "chave_fora_da_faixa", "codigo fixo, mesmo criterio de Cesar")


func teste_vigenere_chave_incorreta() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao_vigenere(), _desafio_vigenere(), 1, _resultado("cifrar pacote chave=cao"))
	afirmar_igual(veredicto.codigo_erro, "chave_incorreta", "'cao' nao e a chave esperada ('gato')")


func teste_vigenere_sucesso_ativa_protecao() -> void:
	var veredicto: VeredictoComando = ResolvedorComando.resolver(
		_configuracao_vigenere(), _desafio_vigenere(), 1, _resultado("cifrar pacote chave=gato"))
	afirmar_igual(veredicto.resultado, CatalogoResultados.SUCESSO, "chave correta")
	afirmar_verdadeiro(veredicto.resolveu_desafio, "desafio resolvido")
	afirmar_igual(veredicto.delta_pontos, 150, "bonus de primeira tentativa")
