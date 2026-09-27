class_name AnalisadorLexico
extends RefCounted

## AFD (automato finito deterministico) do terminal de comandos.
##
## Reconhece os tokens da tabela da secao 6 do CLAUDE.md caractere a caractere,
## por transicao de estado explicita -- sem RegEx por baixo. E o motor lexico
## que a banca cobrou ver de verdade (apontamento 5): a etapa lexica so sabe
## formar tokens a partir do alfabeto da linguagem, e nao sabe nada de
## gramatica, verbo permitido ou fase. Essa camada mora em
## analisador_sintatico.gd e no resolvedor semantico.
##
## Este AFD assume texto ja normalizado (trim + minusculas) por quem chama --
## normalizar nao e responsabilidade lexica, e repetir a normalizacao aqui so
## esconderia um bug de quem esqueceu de normalizar antes.

## Palavras reservadas da GRAMATICA global (BNF da secao 6). Isto NAO e
## FaseConfig.verbos_permitidos: aquela lista restringe semanticamente o que
## uma fase aceita; esta lista e o alfabeto inteiro que o AFD reconhece como
## VERBO em qualquer fase. "cyfrar" nao esta aqui, entao vira IDENTIFICADOR --
## token lexicamente valido, que o parser rejeita por estar na posicao errada.
const VERBOS_DA_GRAMATICA: PackedStringArray = [
	"cifrar", "decifrar", "hash", "verificar", "dica", "status",
]


static func tokenizar(texto: String) -> ResultadoLexico:
	var tokens: Array[Token] = []
	var posicao: int = 0
	var tamanho: int = texto.length()

	while posicao < tamanho:
		var caractere: String = texto[posicao]

		if caractere == " " or caractere == "\t":
			posicao += 1
			continue

		if caractere == "=":
			tokens.append(Token.new(Token.Tipo.ATRIBUICAO, "=", posicao))
			posicao += 1
			continue

		if _e_letra(caractere):
			var inicio: int = posicao
			posicao += 1
			while posicao < tamanho and _e_letra_digito_ou_underscore(texto[posicao]):
				posicao += 1
			var lexema: String = texto.substr(inicio, posicao - inicio)
			var tipo: Token.Tipo = Token.Tipo.VERBO if VERBOS_DA_GRAMATICA.has(lexema) \
				else Token.Tipo.IDENTIFICADOR
			tokens.append(Token.new(tipo, lexema, inicio))
			continue

		if _e_digito(caractere):
			var inicio_numero: int = posicao
			posicao += 1
			while posicao < tamanho and _e_digito(texto[posicao]):
				posicao += 1
			tokens.append(Token.new(
				Token.Tipo.NUMERO, texto.substr(inicio_numero, posicao - inicio_numero), inicio_numero))
			continue

		# Nenhuma transicao do automato aceita este caractere a partir do estado
		# inicial: erro lexico de verdade, e nao um problema de gramatica.
		return ResultadoLexico.falha(caractere, posicao)

	tokens.append(Token.new(Token.Tipo.EOF, "", tamanho))
	return ResultadoLexico.sucesso(tokens)


static func _e_letra(caractere: String) -> bool:
	return caractere >= "a" and caractere <= "z"


static func _e_digito(caractere: String) -> bool:
	return caractere >= "0" and caractere <= "9"


static func _e_letra_digito_ou_underscore(caractere: String) -> bool:
	return _e_letra(caractere) or _e_digito(caractere) or caractere == "_"
