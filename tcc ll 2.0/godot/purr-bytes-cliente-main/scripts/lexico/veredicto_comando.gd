class_name VeredictoComando
extends RefCounted

## Saida de ResolvedorComando.resolver(): o veredito FINAL de uma tentativa,
## ja incluindo a etapa semantica, mais os efeitos de jogo que fase_base.gd
## precisa aplicar (pontos, protecao, avanco de desafio). Separar o veredito
## (dado) de quem aplica o efeito (fase_base.gd) e o que deixa esta classe
## testavel sem instanciar uma cena.

var resultado: String = CatalogoResultados.ERRO_SEMANTICO
var codigo_erro: String = ""
var texto_para_terminal: String = ""

var resolveu_desafio: bool = false
var delta_pontos: int = 0
var duracao_protecao_s: float = 0.0
## QUAL cifra a protecao concedida usa -- e ela que decide de quais cachorros o
## jogador esta protegido (cada cor exige a sua). Vazio quando o veredito nao
## concede protecao nenhuma.
var algoritmo_protecao: String = ""
var dica_solicitada: bool = false


static func semantico(codigo_erro_: String, texto_: String) -> VeredictoComando:
	var v := VeredictoComando.new()
	v.resultado = CatalogoResultados.ERRO_SEMANTICO
	v.codigo_erro = codigo_erro_
	v.texto_para_terminal = texto_
	return v


static func sucesso(texto_: String) -> VeredictoComando:
	var v := VeredictoComando.new()
	v.resultado = CatalogoResultados.SUCESSO
	v.texto_para_terminal = texto_
	return v
