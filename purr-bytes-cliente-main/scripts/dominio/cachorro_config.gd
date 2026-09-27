class_name CachorroConfig
extends Resource

## Um cachorro farejador dentro de uma fase -- dado puro, como DesafioConfig.
##
## Cada cachorro exige UM algoritmo: so a cifra correspondente protege contra
## ele. E dai que sai a licao da mecanica: "cifrei" nao basta, tem que ser a
## cifra certa para aquele interceptador.
##
## A COR e separada disso: e identidade visual do cachorro, escolhida em `cor`,
## e no futuro devera dar lugar a um sprite proprio. Ela nasce com a cor do
## algoritmo so como default conveniente -- quem pinta o cachorro e este
## recurso, nao a tabela de legenda.
##
## Acrescentar cachorro a uma fase e acrescentar um item nesta lista dentro do
## .tres -- nenhuma linha de codigo em cenas/fases/, que continuam sem script.

@export var identificador: String = "cachorro"

## Precisa ser um algoritmo conhecido. Fora disso o cachorro ficaria invencivel
## -- FaseConfig.problemas() recusa a fase.
@export_enum("CESAR", "VIGENERE", "SHA256", "AES") var algoritmo_exigido: String = "CESAR"

## Identidade visual do cachorro. Transparente (alpha 0) significa "use a cor
## do algoritmo como default", que e o caso das fases atuais; qualquer outro
## valor e respeitado como escolhido a mao.
##
## Existe como campo proprio, e nao derivado do algoritmo, porque cor e regra
## sao coisas diferentes: dois cachorros podem exigir a mesma cifra e ter
## aparencias distintas, e a aparencia vai virar sprite um dia sem que a regra
## mude uma linha.
@export var cor: Color = Color(0, 0, 0, 0)

## COMO este cachorro e bloqueado -- os tres modos que o jogo tem:
##
##   CIFRA   (padrao) -- so a cifra de `algoritmo_exigido` protege. E o modo das
##                       fases 1 a 3 do TCC, preservado intacto.
##   COMANDO          -- so digitar `comando_para_bloquear` protege. Modo das
##                       fases criadas no editor.
##   NENHUM           -- nada bloqueia: ele so persegue, e a unica defesa e a
##                       rota. E o que o editor grava quando o professor deixa o
##                       comando em branco.
##
## O modo e explicito, e nao inferido de "o comando esta vazio?": a diferenca
## entre "nao tem comando porque usa cifra" e "nao tem comando porque so
## persegue" e real, e inferir faria a validacao de justica cobrar cifra de um
## cachorro que nunca foi feito para ser enganado.
@export_enum("CIFRA", "COMANDO", "NENHUM") var modo_de_bloqueio: String = "CIFRA"

## Comando em TEXTO LIVRE que bloqueia este cachorro, digitado no terminal.
##
## E o modelo de autoria: o professor escreve o comando que quer ensinar, sem
## depender do enum de algoritmos. Comparacao EXATA (inclusive maiusculas e
## espacos nas pontas ja aparados) -- o jogador precisa digitar o que a fase
## pede, nao algo parecido.
##
## Vazio = este cachorro NAO e bloqueavel por comando: ele so persegue, e a
## unica defesa e a rota. Vazio tambem e o caso das fases 1 a 3, que continuam
## usando a protecao por algoritmo (algoritmo_exigido).
@export var comando_para_bloquear: String = ""

## Vigia de CIFRA criado no editor: a palavra que o jogador protege e a chave.
## A fase transforma isso num DesafioConfig (CarregadorFaseJson), e o comando
## passa pelo analisador lexico-sintatico e pela cifra de verdade -- ao
## contrario do comando livre, que e comparado como texto. Vazios nas fases em
## que o desafio ja vem pronto no FaseConfig.
@export var palavra_da_cifra: String = ""
## Cesar: deslocamento (1..25). Vigenere: palavra-chave. SHA-256: vazio (hash
## nao tem chave).
@export var chave_da_cifra: String = ""


## O que o jogador digita para enganar este vigia de cifra -- o mesmo texto
## que a legenda de comandos mostra. Vazio quando nao ha palavra configurada.
func comando_da_cifra() -> String:
	if palavra_da_cifra.is_empty():
		return ""
	if algoritmo_exigido == "SHA256":
		return "hash %s, depois verificar %s <prefixo>" % [palavra_da_cifra, palavra_da_cifra]
	return "cifrar %s chave=%s" % [palavra_da_cifra, chave_da_cifra]


func bloqueia_por_comando() -> bool:
	return modo_de_bloqueio == "COMANDO" and not comando_para_bloquear.strip_edges().is_empty()


func bloqueia_por_cifra() -> bool:
	return modo_de_bloqueio == "CIFRA"


## Nada o bloqueia: so perseguir. Nao e bug nem fase mal configurada -- e uma
## ameaca da qual se foge, e o editor permite isso de proposito.
func apenas_persegue() -> bool:
	return modo_de_bloqueio == "NENHUM" \
		or (modo_de_bloqueio == "COMANDO" and comando_para_bloquear.strip_edges().is_empty())

## Celula do labirinto (coordenada de TileMapLayer, nao pixel) onde ele nasce.
## Em celula, e nao em pixel, porque e assim que o mapa e escrito e conferido.
@export var celula_inicial: Vector2i = Vector2i(1, 1)

## Rota de patrulha, em celulas, percorrida em ciclo enquanto ele nao tem
## linha de visao nem alvo do Diretor. Vazia = sem patrulha (comportamento
## historico do Marco 1: perseguir a posicao do jogador).
@export var ancoras: Array[Vector2i] = []

## 0 = herda FaseConfig.velocidade_cachorro / alcance_deteccao_cachorro. Existe
## para uma fase poder ter um cachorro lento de patrulha longa e outro rapido
## de area pequena sem duplicar os campos da fase inteira.
@export_range(0.0, 200.0, 1.0) var velocidade: float = 0.0
@export_range(0.0, 400.0, 1.0) var alcance_deteccao: float = 0.0


## A cor que este cachorro veste: a escolhida, ou a do algoritmo quando nenhuma
## foi escolhida.
func cor_efetiva() -> Color:
	return cor if cor.a > 0.0 else LegendaCores.cor(algoritmo_exigido)


func problemas() -> PackedStringArray:
	var lista := PackedStringArray()
	if identificador.strip_edges().is_empty():
		lista.append("cachorro sem identificador")
	if not LegendaCores.conhece(algoritmo_exigido):
		lista.append("cachorro '%s' exige o algoritmo desconhecido '%s' (sem cor na legenda)"
			% [identificador, algoritmo_exigido])
	return lista
