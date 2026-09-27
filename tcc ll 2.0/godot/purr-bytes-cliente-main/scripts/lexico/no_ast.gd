class_name NoAst
extends RefCounted

## No da AST produzida por analisador_sintatico.gd a partir da BNF da secao 6:
##
##   <comando> ::= <verbo> <lista_arg> EOF
##
## Um NoAst representa o comando inteiro: o verbo e a lista de argumentos, ja
## separados entre pares "chave=valor" e argumentos soltos (identificador ou
## numero). A validacao SEMANTICA (verbo permitido na fase, chave dentro da
## faixa, chave que resolve o desafio) nao mora aqui -- este no so descreve o
## que a gramatica aceitou, nao o que a fase faz com isso.

class Argumento:
	extends RefCounted
	var chave: String = ""    # vazio quando o argumento nao e um par_chave
	var valor: String = ""
	var e_par_chave: bool = false

	static func par(chave_: String, valor_: String) -> Argumento:
		var a := Argumento.new()
		a.chave = chave_
		a.valor = valor_
		a.e_par_chave = true
		return a

	static func solto(valor_: String) -> Argumento:
		var a := Argumento.new()
		a.valor = valor_
		a.e_par_chave = false
		return a


var verbo: String = ""
var argumentos: Array[Argumento] = []


## Valor do primeiro par_chave com este nome, ou "" se nao houver. Na gramatica
## da fase 1 a 3 so existe "chave", mas o metodo fica geral por nome mesmo assim
## -- generalizar aqui e mais barato que reabrir o parser depois.
func par_chave(nome: String) -> String:
	for argumento: Argumento in argumentos:
		if argumento.e_par_chave and argumento.chave == nome:
			return argumento.valor
	return ""


func tem_par_chave(nome: String) -> bool:
	for argumento: Argumento in argumentos:
		if argumento.e_par_chave and argumento.chave == nome:
			return true
	return false


func argumentos_soltos() -> Array[String]:
	var soltos: Array[String] = []
	for argumento: Argumento in argumentos:
		if not argumento.e_par_chave:
			soltos.append(argumento.valor)
	return soltos
