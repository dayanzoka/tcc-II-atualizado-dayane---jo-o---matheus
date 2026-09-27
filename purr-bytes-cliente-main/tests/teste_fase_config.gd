extends CasoDeTeste

## FaseConfig e o unico ponto de configuracao de uma fase. Se ele aceitar dado
## incoerente calado, o erro so aparece com a fase rodando -- ou, pior, na
## ingestao, com a telemetria da fase inteira sendo recusada por causa de um
## numero de fase fora de 1..4.


func teste_configuracao_valida_nao_tem_problema() -> void:
	var config: FaseConfig = _fase_cesar()
	afirmar_tamanho(config.problemas(), 0,
		"configuracao coerente passa: %s" % ", ".join(config.problemas()))
	afirmar_verdadeiro(config.valida(), "valida() concorda com problemas()")


func teste_numero_fora_da_faixa_do_banco() -> void:
	var config: FaseConfig = _fase_cesar()
	config.numero = 7
	afirmar_verdadeiro(_tem_problema(config, "fora de 1..4"),
		"numero fora de 1..4 e recusado (CHECK do banco)")


func teste_fase_sem_desafio_e_sem_verbo() -> void:
	var config: FaseConfig = _fase_cesar()
	config.desafios = []
	afirmar_verdadeiro(_tem_problema(config, "nenhum desafio"), "fase vazia e recusada")

	var outra: FaseConfig = _fase_cesar()
	outra.verbos_permitidos = PackedStringArray()
	afirmar_verdadeiro(_tem_problema(outra, "verbos_permitidos vazio"),
		"fase sem verbo recusaria qualquer comando do jogador")


func teste_verbo_do_desafio_precisa_estar_permitido() -> void:
	var config: FaseConfig = _fase_cesar()
	config.desafios[0].verbo_esperado = "hashear"
	afirmar_verdadeiro(_tem_problema(config, "nao esta em verbos_permitidos"),
		"desafio que espera verbo nao permitido e impossivel de resolver")


func teste_identificador_repetido() -> void:
	var config: FaseConfig = _fase_cesar()
	config.desafios.append(_desafio("cesar-01", "cifrar"))
	afirmar_verdadeiro(_tem_problema(config, "repetido"),
		"identificador repetido misturaria tentativas de desafios diferentes na analise")


func teste_identificador_cabe_no_banco() -> void:
	var config: FaseConfig = _fase_cesar()
	config.desafios[0].identificador = "x".repeat(61)
	afirmar_verdadeiro(_tem_problema(config, "60 caracteres"),
		"identificador acima de VARCHAR(60) e recusado antes de virar dado")


func teste_faixa_de_chave_invertida() -> void:
	var config: FaseConfig = _fase_cesar()
	config.faixa_chave_minima = 20
	config.faixa_chave_maxima = 3
	afirmar_verdadeiro(_tem_problema(config, "faixa de chave invertida"),
		"faixa invertida tornaria toda chave invalida")


func teste_busca_de_desafio_por_identificador() -> void:
	var config: FaseConfig = _fase_cesar()
	afirmar_nao_nulo(config.desafio_por_identificador("cesar-01"), "acha o desafio existente")
	afirmar_nulo(config.desafio_por_identificador("inexistente"), "nao inventa desafio")


## Uma fase 1 plausivel, para os testes negativos partirem de algo valido.
func _fase_cesar() -> FaseConfig:
	var config := FaseConfig.new()
	config.numero = 1
	config.titulo = "cifra de Cesar"
	config.algoritmo = "CESAR"
	config.verbos_permitidos = PackedStringArray(["cifrar", "decifrar", "dica", "status"])
	config.desafios = [_desafio("cesar-01", "cifrar")]
	return config


func _desafio(identificador: String, verbo: String) -> DesafioConfig:
	var desafio := DesafioConfig.new()
	desafio.identificador = identificador
	desafio.enunciado = "proteja o pacote antes de atravessar"
	desafio.texto_claro = "pacote"
	desafio.chave_esperada = "3"
	desafio.verbo_esperado = verbo
	return desafio


func _tem_problema(config: FaseConfig, trecho: String) -> bool:
	for problema: String in config.problemas():
		if problema.contains(trecho):
			return true
	return false
