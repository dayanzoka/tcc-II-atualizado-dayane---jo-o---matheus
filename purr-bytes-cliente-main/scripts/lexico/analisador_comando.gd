class_name AnalisadorComando
extends RefCounted

## Ponto de entrada do pipeline lexico-sintatico do terminal: normaliza,
## tokeniza (AnalisadorLexico) e faz o parsing (AnalisadorSintatico).
##
## Deliberadamente nao sabe nada de FaseConfig, DesafioConfig ou verbo
## permitido -- isso e semantica de jogo, nao de linguagem, e mora em
## scripts/lexico/resolvedor_comando.gd. Manter a fronteira aqui e o que deixa
## o Marco 2 (Vigenere) reaproveitar este arquivo inteiro sem tocar uma linha:
## se Vigenere precisasse mudar o parser, a generalizacao teria falhado
## (ver CLAUDE.md, planejamento do Marco 2).

const _CODIGO_CARACTERE_INVALIDO: String = "caractere_invalido"
const _CODIGO_TOKEN_INESPERADO: String = "token_inesperado"


static func analisar(texto_bruto: String) -> ResultadoComando:
	var resultado := ResultadoComando.new()
	resultado.texto_normalizado = texto_bruto.strip_edges().to_lower()

	var lexico: ResultadoLexico = AnalisadorLexico.tokenizar(resultado.texto_normalizado)
	if not lexico.ok:
		resultado.resultado = CatalogoResultados.ERRO_LEXICO
		resultado.codigo_erro = _CODIGO_CARACTERE_INVALIDO
		return resultado

	resultado.tokens = lexico.tokens

	var sintatico: ResultadoSintatico = AnalisadorSintatico.analisar(lexico.tokens)
	if not sintatico.ok:
		resultado.resultado = CatalogoResultados.ERRO_SINTATICO
		resultado.codigo_erro = _CODIGO_TOKEN_INESPERADO
		return resultado

	resultado.ast = sintatico.ast
	# Provisorio: quem chama (ResolvedorComando) ainda decide entre SUCESSO e
	# ERRO_SEMANTICO com base no FaseConfig e no desafio corrente.
	resultado.resultado = CatalogoResultados.SUCESSO
	return resultado
