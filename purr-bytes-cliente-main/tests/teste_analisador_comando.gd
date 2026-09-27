extends CasoDeTeste

## Pipeline completo (normalizar -> lexico -> sintatico), sem semantica --
## ERRO_SEMANTICO nao existe neste nivel porque so quem conhece o FaseConfig e
## o desafio corrente pode decidir isso (scripts/lexico/resolvedor_comando.gd,
## testado em tests/teste_resolvedor_comando.gd).


func teste_comando_valido_e_sucesso_provisorio() -> void:
	var resultado: ResultadoComando = AnalisadorComando.analisar("cifrar pacote chave=3")
	afirmar_igual(resultado.resultado, CatalogoResultados.SUCESSO,
		"lexico e sintatico passam; semantica fica para o resolvedor")
	afirmar_verdadeiro(resultado.passou_lexico_e_sintatico(), "AST presente")
	afirmar_igual(resultado.ast.verbo, "cifrar", "AST reflete o comando")
	afirmar_igual(resultado.codigo_erro, "", "sem codigo_erro em sucesso provisorio")


func teste_normaliza_espacos_e_maiusculas_antes_de_tokenizar() -> void:
	var resultado: ResultadoComando = AnalisadorComando.analisar("  CIFRAR   Pacote  Chave=3  ")
	afirmar_igual(resultado.texto_normalizado, "cifrar   pacote  chave=3",
		"trim nas pontas e minusculas -- espacos internos nao sao colapsados aqui, "
		+ "isso e responsabilidade da sanitizacao de Telemetria antes do envio")
	afirmar_igual(resultado.resultado, CatalogoResultados.SUCESSO, "normalizado tokeniza normalmente")


func teste_erro_lexico_tem_codigo_fixo() -> void:
	var resultado: ResultadoComando = AnalisadorComando.analisar("cifrar pacote!")
	afirmar_igual(resultado.resultado, CatalogoResultados.ERRO_LEXICO, "caractere fora do alfabeto")
	afirmar_igual(resultado.codigo_erro, "caractere_invalido", "codigo_erro fixo e curto (VARCHAR(40))")


func teste_erro_sintatico_tem_codigo_fixo() -> void:
	var resultado: ResultadoComando = AnalisadorComando.analisar("pacote chave=3")
	afirmar_igual(resultado.resultado, CatalogoResultados.ERRO_SINTATICO, "falta o VERBO inicial")
	afirmar_igual(resultado.codigo_erro, "token_inesperado", "codigo_erro fixo e curto (VARCHAR(40))")


func teste_tc04_pipeline_completo() -> void:
	var resultado: ResultadoComando = AnalisadorComando.analisar("cyfrar pacote chave=3")
	afirmar_igual(resultado.resultado, CatalogoResultados.ERRO_SINTATICO,
		"TC-04 fim a fim: 'cyfrar' tokeniza como IDENTIFICADOR e o parser rejeita por faltar VERBO")


func teste_tokens_no_formato_de_telemetria() -> void:
	var resultado: ResultadoComando = AnalisadorComando.analisar("cifrar pacote chave=3")
	var tokens: Array[Dictionary] = resultado.tokens_para_telemetria()
	afirmar_igual(tokens.size(), 6, "VERBO IDENTIFICADOR IDENTIFICADOR ATRIBUICAO NUMERO EOF")
	for token: Dictionary in tokens:
		afirmar_verdadeiro(token.has("tipo") and token.has("lexema") and token.has("posicao"),
			"cada token tem tipo, lexema e posicao -- formato que Telemetria.registrar_tentativa espera")
