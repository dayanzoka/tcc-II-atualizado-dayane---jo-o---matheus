extends CasoDeTeste

## AFD isolado, sem parser nem semantica: so confere que cada caractere do
## alfabeto da linguagem forma o token certo, e que o que esta fora do alfabeto
## produz ERRO_LEXICO com a posicao certa.


func teste_verbo_da_gramatica_vira_token_verbo() -> void:
	var resultado: ResultadoLexico = AnalisadorLexico.tokenizar("cifrar")
	afirmar_verdadeiro(resultado.ok, "tokeniza sem erro")
	afirmar_igual(resultado.tokens.size(), 2, "VERBO + EOF")
	afirmar_igual(resultado.tokens[0].tipo, Token.Tipo.VERBO, "cifrar e VERBO")
	afirmar_igual(resultado.tokens[0].lexema, "cifrar", "lexema preservado")
	afirmar_igual(resultado.tokens[1].tipo, Token.Tipo.EOF, "ultimo token e EOF")


## O AFD nao sabe de gramatica: uma palavra fora da tabela de verbos e um
## IDENTIFICADOR lexicamente valido, nao um erro. O erro (se houver) e do
## parser, nao do automato -- ver docs/decisoes/0006-analisador-lexico-sintatico.md.
func teste_palavra_fora_da_tabela_de_verbos_vira_identificador() -> void:
	var resultado: ResultadoLexico = AnalisadorLexico.tokenizar("cyfrar")
	afirmar_verdadeiro(resultado.ok, "cyfrar e um token valido para o AFD")
	afirmar_igual(resultado.tokens[0].tipo, Token.Tipo.IDENTIFICADOR,
		"palavra reservada mal escrita cai como IDENTIFICADOR, nao como erro lexico")


func teste_numero_e_atribuicao() -> void:
	var resultado: ResultadoLexico = AnalisadorLexico.tokenizar("chave=3")
	afirmar_verdadeiro(resultado.ok, "tokeniza sem erro")
	afirmar_igual(resultado.tokens.size(), 4, "IDENTIFICADOR(chave) ATRIBUICAO NUMERO EOF")
	afirmar_igual(resultado.tokens[0].tipo, Token.Tipo.IDENTIFICADOR, "'chave' e IDENTIFICADOR")
	afirmar_igual(resultado.tokens[1].tipo, Token.Tipo.ATRIBUICAO, "'=' e ATRIBUICAO")
	afirmar_igual(resultado.tokens[2].tipo, Token.Tipo.NUMERO, "'3' e NUMERO")
	afirmar_igual(resultado.tokens[2].lexema, "3", "lexema do numero preservado")


func teste_comando_completo() -> void:
	var resultado: ResultadoLexico = AnalisadorLexico.tokenizar("cifrar pacote chave=3")
	afirmar_verdadeiro(resultado.ok, "tokeniza sem erro")
	afirmar_igual(resultado.tokens.size(), 6,
		"VERBO IDENTIFICADOR IDENTIFICADOR ATRIBUICAO NUMERO EOF")
	var tipos: Array[Token.Tipo] = []
	for token: Token in resultado.tokens:
		tipos.append(token.tipo)
	afirmar_igual(tipos, [
		Token.Tipo.VERBO, Token.Tipo.IDENTIFICADOR, Token.Tipo.IDENTIFICADOR,
		Token.Tipo.ATRIBUICAO, Token.Tipo.NUMERO, Token.Tipo.EOF,
	], "sequencia de tipos do comando completo")


func teste_espacos_multiplos_sao_apenas_separadores() -> void:
	var resultado: ResultadoLexico = AnalisadorLexico.tokenizar("cifrar   pacote")
	afirmar_verdadeiro(resultado.ok, "tokeniza sem erro")
	afirmar_igual(resultado.tokens.size(), 3, "VERBO IDENTIFICADOR EOF -- espaco extra nao vira token")


func teste_caractere_fora_do_alfabeto_e_erro_lexico() -> void:
	var resultado: ResultadoLexico = AnalisadorLexico.tokenizar("cifrar pacote!")
	afirmar_falso(resultado.ok, "'!' nao tem transicao no automato")
	afirmar_igual(resultado.caractere_invalido, "!", "aponta o caractere que falhou")
	afirmar_igual(resultado.posicao_erro, 13, "aponta a posicao exata do caractere")


func teste_identificador_aceita_digito_e_underscore_apos_a_primeira_letra() -> void:
	var resultado: ResultadoLexico = AnalisadorLexico.tokenizar("pacote_2")
	afirmar_verdadeiro(resultado.ok, "tokeniza sem erro")
	afirmar_igual(resultado.tokens[0].lexema, "pacote_2", "digito e underscore fazem parte do lexema")


func teste_string_vazia_produz_so_eof() -> void:
	var resultado: ResultadoLexico = AnalisadorLexico.tokenizar("")
	afirmar_verdadeiro(resultado.ok, "string vazia nao e erro lexico")
	afirmar_igual(resultado.tokens.size(), 1, "so o EOF")
	afirmar_igual(resultado.tokens[0].tipo, Token.Tipo.EOF, "unico token e EOF")
