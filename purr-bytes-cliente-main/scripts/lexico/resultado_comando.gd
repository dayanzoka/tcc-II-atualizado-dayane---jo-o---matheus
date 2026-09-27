class_name ResultadoComando
extends RefCounted

## Saida do pipeline lexico-sintatico (scripts/lexico/analisador_comando.gd).
##
## resultado e codigo_erro aqui usam exatamente o vocabulario de
## CatalogoResultados: em ERRO_LEXICO ou ERRO_SINTATICO, este e o veredito
## final. Em SUCESSO, e um veredito PROVISORIO -- falta a etapa semantica
## (scripts/lexico/resolvedor_comando.gd), que pode ainda rebaixar para
## ERRO_SEMANTICO (verbo nao permitido na fase, chave fora da faixa, chave que
## nao resolve o desafio).

var texto_normalizado: String = ""
var resultado: String = CatalogoResultados.ERRO_LEXICO
var codigo_erro: String = ""
var tokens: Array[Token] = []
var ast: NoAst = null


func passou_lexico_e_sintatico() -> bool:
	return resultado == CatalogoResultados.SUCESSO and ast != null


## Formato que Telemetria.registrar_tentativa() espera em tentativa_comando.tokens.
func tokens_para_telemetria() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for token: Token in tokens:
		lista.append(token.para_dicionario())
	return lista
