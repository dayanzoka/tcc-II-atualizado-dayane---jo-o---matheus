extends CasoDeTeste

## Parser isolado: recebe tokens ja prontos (sem passar pelo AFD) e confere a
## AST contra a BNF da secao 6. Erros de gramatica aqui sao sempre
## ERRO_SINTATICO por definicao -- quem decide o CODIGO de resultado
## (LEXICO/SINTATICO) e AnalisadorComando; este arquivo so olha para
## ResultadoSintatico.ok e para a AST.


func _tokenizar(texto: String) -> Array[Token]:
	var resultado: ResultadoLexico = AnalisadorLexico.tokenizar(texto)
	assert(resultado.ok, "teste mal escrito: texto deveria ser lexicamente valido")
	return resultado.tokens


func teste_comando_minimo_sem_argumentos() -> void:
	var resultado: ResultadoSintatico = AnalisadorSintatico.analisar(_tokenizar("status"))
	afirmar_verdadeiro(resultado.ok, "verbo sozinho e um comando valido")
	afirmar_igual(resultado.ast.verbo, "status", "verbo capturado na AST")
	afirmar_tamanho(resultado.ast.argumentos, 0, "sem argumentos")


func teste_comando_com_par_chave() -> void:
	var resultado: ResultadoSintatico = AnalisadorSintatico.analisar(_tokenizar("cifrar pacote chave=3"))
	afirmar_verdadeiro(resultado.ok, "comando completo e valido")
	afirmar_igual(resultado.ast.verbo, "cifrar", "verbo")
	afirmar_igual(resultado.ast.argumentos_soltos(), ["pacote"], "argumento solto preservado")
	afirmar_verdadeiro(resultado.ast.tem_par_chave("chave"), "par_chave reconhecido")
	afirmar_igual(resultado.ast.par_chave("chave"), "3", "valor do par_chave")


func teste_chave_com_valor_alfabetico_vigenere() -> void:
	# O mesmo parser atende Vigenere (Marco 2) sem mudar uma linha: chave pode
	# ser IDENTIFICADOR ou NUMERO por definicao da BNF.
	var resultado: ResultadoSintatico = AnalisadorSintatico.analisar(_tokenizar("cifrar pacote chave=gato"))
	afirmar_verdadeiro(resultado.ok, "chave alfabetica e sintaticamente valida")
	afirmar_igual(resultado.ast.par_chave("chave"), "gato", "valor alfabetico do par_chave")


func teste_identificador_chamado_chave_sem_atribuicao_e_argumento_solto() -> void:
	# "chave" sem "=" depois nao abre par_chave -- e so mais um IDENTIFICADOR
	# solto. O lookahead de um token e o que faz essa diferenca.
	var resultado: ResultadoSintatico = AnalisadorSintatico.analisar(_tokenizar("status chave"))
	afirmar_verdadeiro(resultado.ok, "'chave' sem '=' e argumento solto valido")
	afirmar_igual(resultado.ast.argumentos_soltos(), ["chave"], "'chave' entra como valor solto")
	afirmar_falso(resultado.ast.tem_par_chave("chave"), "nao vira par_chave sem ATRIBUICAO")


func teste_verbo_ausente_e_erro_sintatico() -> void:
	var resultado: ResultadoSintatico = AnalisadorSintatico.analisar(_tokenizar("pacote chave=3"))
	afirmar_falso(resultado.ok, "comando tem que comecar com VERBO")
	afirmar_igual(resultado.esperado, "VERBO", "parser aponta o que faltou")
	afirmar_igual(resultado.token_inesperado.tipo, Token.Tipo.IDENTIFICADOR,
		"o token que quebrou a derivacao e o IDENTIFICADOR na posicao do verbo")


## O caso TC-04 da monografia: "cyfrar" nao e reconhecido como VERBO pelo AFD
## (vira IDENTIFICADOR, ver teste_analisador_lexico.gd), e e o PARSER quem
## rejeita por a gramatica exigir VERBO na primeira posicao. Decisao registrada
## em docs/decisoes/0006-analisador-lexico-sintatico.md.
func teste_tc04_verbo_mal_escrito_e_erro_sintatico_nao_lexico() -> void:
	var lexico: ResultadoLexico = AnalisadorLexico.tokenizar("cyfrar pacote chave=3")
	afirmar_verdadeiro(lexico.ok, "TC-04: o AFD tokeniza 'cyfrar' normalmente (vira IDENTIFICADOR)")

	var sintatico: ResultadoSintatico = AnalisadorSintatico.analisar(lexico.tokens)
	afirmar_falso(sintatico.ok, "TC-04: a gramatica rejeita por faltar VERBO na primeira posicao")
	afirmar_igual(sintatico.token_inesperado.lexema, "cyfrar", "o token rejeitado e 'cyfrar'")


func teste_par_chave_sem_valor_e_erro_sintatico() -> void:
	var resultado: ResultadoSintatico = AnalisadorSintatico.analisar(_tokenizar("cifrar pacote chave="))
	afirmar_falso(resultado.ok, "par_chave exige IDENTIFICADOR ou NUMERO depois do '='")
	afirmar_igual(resultado.esperado, "IDENTIFICADOR ou NUMERO", "mensagem indica o que faltou")


func teste_token_sobrando_apos_comando_valido_e_erro_sintatico() -> void:
	# "=" sozinho depois de um comando completo nao encaixa em <lista_arg>
	# nenhuma producao, entao <comando> exige EOF ali e nao encontra.
	var resultado: ResultadoSintatico = AnalisadorSintatico.analisar(_tokenizar("status ="))
	afirmar_falso(resultado.ok, "token que nao inicia <argumento> antes do EOF e erro sintatico")
	afirmar_igual(resultado.esperado, "EOF", "esperava EOF e achou outro token")


func teste_varios_argumentos_soltos_e_par_chave_misturados() -> void:
	var resultado: ResultadoSintatico = AnalisadorSintatico.analisar(
		_tokenizar("verificar pacote 7 chave=3"))
	afirmar_verdadeiro(resultado.ok, "argumentos soltos e par_chave podem se misturar em qualquer ordem")
	afirmar_igual(resultado.ast.argumentos_soltos(), ["pacote", "7"], "dois argumentos soltos, em ordem")
	afirmar_igual(resultado.ast.par_chave("chave"), "3", "par_chave capturado mesmo apos os soltos")
