class_name Cifra
extends RefCounted

## Contrato comum das cifras de fase (scripts/cripto/cesar.gd no Marco 1,
## scripts/cripto/vigenere.gd no Marco 2).
##
## Existe para o resolvedor de comando poder escolher a cifra a partir de
## FaseConfig.algoritmo sem crescer um match por fase -- e o proprio requisito
## nao funcional da secao 1 (nova fase, baixo esforco de codificacao) aplicado
## aqui: adicionar Vigenere e implementar esta classe de novo, nao reabrir o
## resolvedor.
##
## chave entra e sai como String de proposito: "3" para Cesar, "gato" para
## Vigenere -- o mesmo DesafioConfig.chave_esperada (tambem String) atende os
## dois algoritmos sem um campo por tipo.

func cifrar(_texto: String, _chave: String) -> String:
	push_error("Cifra.cifrar() e abstrato -- implemente na subclasse")
	return ""


func decifrar(_texto: String, _chave: String) -> String:
	push_error("Cifra.decifrar() e abstrato -- implemente na subclasse")
	return ""


## Verdadeiro se a String e sintaticamente aceitavel como chave deste algoritmo
## (Cesar: inteiro; Vigenere: letras). Nao e a mesma coisa que a chave estar na
## faixa semantica da fase (FaseConfig.faixa_chave_minima/maxima) -- isso so o
## chamador sabe, porque so ele conhece a fase corrente.
func chave_sintaticamente_valida(_chave: String) -> bool:
	return false


## "Faixa" nao significa a mesma coisa para todo algoritmo: para Cesar e o
## VALOR da chave; para Vigenere (Marco 2) e o COMPRIMENTO da chave. Deixar
## cada Cifra interpretar isso e o que permite ResolvedorComando validar a
## faixa sem um match por algoritmo -- ver docs/decisoes/0008-vigenere-e-painel-de-demonstracao.md.
func dentro_da_faixa(_chave: String, _minimo: int, _maximo: int) -> bool:
	return false


## Um simbolo de chave por posicao de texto_claro (letra da chave que se
## aplica ali, ou "" onde nao ha deslocamento) -- usado pelo painel de
## demonstracao (CIFRA_DEMONSTRADA, Marco 2). Cesar repete o mesmo simbolo em
## toda posicao com letra; Vigenere avanca pela chave.
func simbolos_de_chave(_texto_claro: String, _chave: String) -> Array[String]:
	return []
