class_name ResultadoLexico
extends RefCounted

## Veredito do AFD (scripts/lexico/analisador_lexico.gd): ou uma lista de tokens,
## ou o caractere e a posicao exatos que nenhuma transicao do automato aceita.
## A posicao do erro e o que permite ao terminal apontar o dedo no lugar certo
## da linha digitada, em vez de so dizer "comando invalido".

var ok: bool = false
var tokens: Array[Token] = []
var caractere_invalido: String = ""
var posicao_erro: int = -1


static func sucesso(tokens_: Array[Token]) -> ResultadoLexico:
	var r := ResultadoLexico.new()
	r.ok = true
	r.tokens = tokens_
	return r


static func falha(caractere_invalido_: String, posicao_erro_: int) -> ResultadoLexico:
	var r := ResultadoLexico.new()
	r.ok = false
	r.caractere_invalido = caractere_invalido_
	r.posicao_erro = posicao_erro_
	return r
