class_name ResultadoSintatico
extends RefCounted

## Veredito do parser recursivo descendente (scripts/lexico/analisador_sintatico.gd):
## ou uma NoAst valida, ou o token que quebrou a derivacao e o que a gramatica
## esperava ali. O token e a posicao (Token.posicao) sao o que permite ao
## terminal apontar exatamente onde a frase parou de fazer sentido.

var ok: bool = false
var ast: NoAst = null
var token_inesperado: Token = null
var esperado: String = ""


static func sucesso(ast_: NoAst) -> ResultadoSintatico:
	var r := ResultadoSintatico.new()
	r.ok = true
	r.ast = ast_
	return r


static func falha(token_inesperado_: Token, esperado_: String) -> ResultadoSintatico:
	var r := ResultadoSintatico.new()
	r.token_inesperado = token_inesperado_
	r.esperado = esperado_
	return r
