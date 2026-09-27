class_name DesafioConfig
extends Resource

## Um desafio de terminal dentro de uma fase.
##
## O CLAUDE.md referencia Array[DesafioConfig] no FaseConfig sem definir o tipo;
## este arquivo o define. E dado puro: nenhum metodo resolve criptografia aqui --
## isso e scripts/cripto/. Se um campo desta lista nao serve para nenhuma das
## fases 1 a 3, ele nao deveria existir (a fase 4 entra por configuracao, nao
## por campo novo).

## Vai para tentativa_comando.desafio, VARCHAR(60). Mantenha curto e estavel:
## e por este identificador que a analise agrupa tentativas do mesmo desafio.
@export var identificador: String = ""

## Texto mostrado ao jogador no terminal.
@export_multiline var enunciado: String = ""

## Conteudo do pacote de dados a ser protegido/verificado.
@export var texto_claro: String = ""

## Chave que resolve o desafio. Numero em texto na fase 1 ("3"), palavra na fase
## 2 ("gato"), vazia na fase 3 (hash nao tem chave). Guardar como String mantem
## um campo unico para os quatro algoritmos.
@export var chave_esperada: String = ""

## Verbo que o desafio espera. Precisa estar em FaseConfig.verbos_permitidos --
## FaseConfig.validar() confere.
@export var verbo_esperado: String = "cifrar"

## Algoritmo DESTE desafio. Vazio = herda FaseConfig.algoritmo, que e o caso da
## maioria. Existe porque a protecao que o jogador ganha ao resolver um desafio
## e a cifra daquele desafio, e a partir da fase 2 uma fase precisa oferecer
## mais de uma: e assim que o jogador consegue produzir a cifra verde para o
## cachorro verde e a azul para o azul dentro da mesma fase. Sem isto, um
## cachorro de cor diferente da fase seria impossivel de enganar.
## Vazio, "CESAR", "VIGENERE", "SHA256" ou "AES" -- e String livre em vez de
## @export_enum porque "herda da fase" precisa ser o vazio, e @export_enum nao
## aceita opcao vazia. problemas() recusa qualquer outro valor.
@export var algoritmo: String = ""

## Resposta textual esperada quando o desafio nao e resolvido por chave (fase 3:
## digest ou prefixo de digest a verificar). Vazio = nao se aplica.
@export var resposta_esperada: String = ""

@export_multiline var dica: String = ""

@export_range(0, 1000, 5) var pontos_acerto: int = 100
@export_range(0, 1000, 5) var pontos_acerto_de_primeira: int = 50
@export_range(0, 1000, 5) var custo_da_dica: int = 25


## O algoritmo que vale para este desafio, ja resolvida a heranca da fase.
func algoritmo_efetivo(algoritmo_da_fase: String) -> String:
	return algoritmo if not algoritmo.is_empty() else algoritmo_da_fase


func problemas() -> PackedStringArray:
	var lista := PackedStringArray()
	if identificador.strip_edges().is_empty():
		lista.append("desafio sem identificador")
	if identificador.length() > 60:
		lista.append("identificador '%s' excede 60 caracteres (tentativa_comando.desafio)"
			% identificador)
	if verbo_esperado.strip_edges().is_empty():
		lista.append("desafio '%s' sem verbo_esperado" % identificador)
	if not algoritmo.is_empty() and not LegendaCores.conhece(algoritmo):
		lista.append("desafio '%s' declara o algoritmo desconhecido '%s'"
			% [identificador, algoritmo])
	return lista
