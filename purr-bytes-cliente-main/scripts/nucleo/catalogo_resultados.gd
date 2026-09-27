class_name CatalogoResultados
extends RefCounted

## Veredito de uma tentativa de comando no terminal.
##
## Espelha a constraint ck_tentativa_resultado de pesquisa.tentativa_comando
## (V2__pesquisa.sql). A distincao entre ERRO_LEXICO e ERRO_SINTATICO e o que a
## banca cobrou no apontamento 5 -- ela nao existe por elegancia, existe porque
## e a evidencia de que o analisador tem duas etapas de verdade.
##
## Quem produz cada um (detalhe na secao 6 do CLAUDE.md):
##   ERRO_LEXICO    -- o AFD nao conseguiu formar um token valido
##   ERRO_SINTATICO -- os tokens sao validos mas a sequencia viola a BNF
##   ERRO_SEMANTICO -- estrutura valida, significado invalido (chave fora da
##                     faixa, verbo nao permitido nesta fase)

const SUCESSO: String = "SUCESSO"
const ERRO_LEXICO: String = "ERRO_LEXICO"
const ERRO_SINTATICO: String = "ERRO_SINTATICO"
const ERRO_SEMANTICO: String = "ERRO_SEMANTICO"
const TIMEOUT: String = "TIMEOUT"
const ABANDONO: String = "ABANDONO"

const TODOS: PackedStringArray = [
	SUCESSO,
	ERRO_LEXICO,
	ERRO_SINTATICO,
	ERRO_SEMANTICO,
	TIMEOUT,
	ABANDONO,
]


static func existe(codigo: String) -> bool:
	return TODOS.has(codigo)
