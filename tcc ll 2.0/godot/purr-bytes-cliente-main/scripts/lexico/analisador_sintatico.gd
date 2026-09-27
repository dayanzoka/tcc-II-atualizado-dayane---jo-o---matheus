class_name AnalisadorSintatico
extends RefCounted

## Parser recursivo descendente para a gramatica da secao 6 do CLAUDE.md:
##
##   <comando>    ::= <verbo> <lista_arg> EOF
##   <verbo>      ::= "cifrar" | "decifrar" | "hash" | "verificar" | "dica" | "status"
##   <lista_arg>  ::= <argumento> <lista_arg> | eps
##   <argumento>  ::= <par_chave> | IDENTIFICADOR | NUMERO
##   <par_chave>  ::= "chave" ATRIBUICAO ( IDENTIFICADOR | NUMERO )
##
## Uma producao por metodo, do jeito que se le a BNF -- e o que torna o parser
## auditavel linha a linha na defesa, em vez de uma tabela de estados opaca.
##
## "chave" nao e palavra reservada da tabela de tokens (so os verbos sao); ela
## chega como um IDENTIFICADOR comum. Quem decide se abre um par_chave e o
## parser, com um token de lookahead (o proximo tem que ser ATRIBUICAO). Isso e
## deliberado: reconhecer "chave=" e trabalho de gramatica, nao de automato
## lexico -- se o AFD tentasse resolver essa ambiguidade, a fronteira entre as
## duas etapas deixaria de existir.

var _tokens: Array[Token] = []
var _indice: int = 0


static func analisar(tokens: Array[Token]) -> ResultadoSintatico:
	var parser := AnalisadorSintatico.new()
	parser._tokens = tokens
	return parser._comando()


func _comando() -> ResultadoSintatico:
	if not _atual_e(Token.Tipo.VERBO):
		return ResultadoSintatico.falha(_atual(), "VERBO")

	var no := NoAst.new()
	no.verbo = _atual().lexema
	_avancar()

	var resultado: ResultadoSintatico = _lista_arg(no)
	if not resultado.ok:
		return resultado

	if not _atual_e(Token.Tipo.EOF):
		return ResultadoSintatico.falha(_atual(), "EOF")

	return ResultadoSintatico.sucesso(no)


func _lista_arg(no: NoAst) -> ResultadoSintatico:
	# <lista_arg> ::= <argumento> <lista_arg> | eps. O eps se resolve por
	# lookahead: um <argumento> so pode comecar com IDENTIFICADOR ou NUMERO
	# (mesmo o par_chave comeca com o IDENTIFICADOR "chave"); qualquer outro
	# token termina a lista sem consumir nada, e quem decide se aquele token
	# faz sentido dali em diante e o chamador (_comando exige EOF em seguida).
	while _atual_e(Token.Tipo.IDENTIFICADOR) or _atual_e(Token.Tipo.NUMERO):
		var resultado: ResultadoSintatico = _argumento(no)
		if not resultado.ok:
			return resultado
	return ResultadoSintatico.sucesso(no)


func _argumento(no: NoAst) -> ResultadoSintatico:
	if _atual_e(Token.Tipo.IDENTIFICADOR) and _atual().lexema == "chave" \
			and _proximo_e(Token.Tipo.ATRIBUICAO):
		return _par_chave(no)

	if _atual_e(Token.Tipo.IDENTIFICADOR) or _atual_e(Token.Tipo.NUMERO):
		no.argumentos.append(NoAst.Argumento.solto(_atual().lexema))
		_avancar()
		return ResultadoSintatico.sucesso(no)

	return ResultadoSintatico.falha(_atual(), "IDENTIFICADOR ou NUMERO")


func _par_chave(no: NoAst) -> ResultadoSintatico:
	_avancar()  # consome o IDENTIFICADOR "chave"

	if not _atual_e(Token.Tipo.ATRIBUICAO):
		return ResultadoSintatico.falha(_atual(), "=")
	_avancar()

	if not (_atual_e(Token.Tipo.IDENTIFICADOR) or _atual_e(Token.Tipo.NUMERO)):
		return ResultadoSintatico.falha(_atual(), "IDENTIFICADOR ou NUMERO")

	no.argumentos.append(NoAst.Argumento.par("chave", _atual().lexema))
	_avancar()
	return ResultadoSintatico.sucesso(no)


# ---------------------------------------------------------------------------
# Cursor de tokens
# ---------------------------------------------------------------------------

func _atual() -> Token:
	return _tokens[_indice]


func _atual_e(tipo: Token.Tipo) -> bool:
	return _atual().tipo == tipo


func _proximo_e(tipo: Token.Tipo) -> bool:
	var proximo_indice: int = _indice + 1
	if proximo_indice >= _tokens.size():
		return false
	return _tokens[proximo_indice].tipo == tipo


func _avancar() -> void:
	# O ultimo token sempre existe e e EOF (o AFD garante isso): parar de
	# avancar nele em vez de estourar o array deixa o parser em erro de
	# gramatica ("esperava X, achei EOF") em vez de erro de indice.
	if _indice < _tokens.size() - 1:
		_indice += 1
