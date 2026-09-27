class_name Token
extends RefCounted

## Um token produzido pelo AFD do analisador lexico (scripts/lexico/analisador_lexico.gd).
##
## O tipo VERBO nao e reconhecido por um padrao de caracteres -- e reconhecido
## por pertencer a tabela de palavras reservadas da GRAMATICA (secao 6 do
## CLAUDE.md: cifrar, decifrar, hash, verificar, dica, status). Uma palavra que
## nao esta nessa lista, mesmo parecendo um comando ("cyfrar"), forma um token
## IDENTIFICADOR valido -- o erro so aparece na etapa seguinte, quando o parser
## exige um VERBO e acha outra coisa. Essa fronteira e proposital: e o que
## separa ERRO_LEXICO de ERRO_SINTATICO no caso TC-04 (ver
## docs/decisoes/0006-analisador-lexico-sintatico.md).

enum Tipo {
	VERBO,
	IDENTIFICADOR,
	NUMERO,
	ATRIBUICAO,
	EOF,
}

var tipo: Tipo
var lexema: String
var posicao: int


func _init(tipo_: Tipo, lexema_: String, posicao_: int) -> void:
	tipo = tipo_
	lexema = lexema_
	posicao = posicao_


static func nome_do_tipo(tipo_: Tipo) -> String:
	match tipo_:
		Tipo.VERBO:
			return "VERBO"
		Tipo.IDENTIFICADOR:
			return "IDENTIFICADOR"
		Tipo.NUMERO:
			return "NUMERO"
		Tipo.ATRIBUICAO:
			return "ATRIBUICAO"
		Tipo.EOF:
			return "EOF"
	return "?"


## Formato que Telemetria.registrar_tentativa() espera em tentativa_comando.tokens
## (array de objetos {tipo, lexema, posicao}).
func para_dicionario() -> Dictionary:
	return {
		"tipo": Token.nome_do_tipo(tipo),
		"lexema": lexema,
		"posicao": posicao,
	}


func _to_string() -> String:
	return "%s(%s)@%d" % [Token.nome_do_tipo(tipo), lexema, posicao]
