class_name DemonstracaoCifra
extends RefCounted

## Monta os dados do painel de demonstração (CIFRA_DEMONSTRADA, Marco 2):
## texto claro, chave alinhada letra a letra e texto cifrado, prontos para uma
## UI iterar posição por posição. Lógica pura, sem nó nenhum -- é o que torna
## o alinhamento testável sem instanciar `cenas/base/painel_cifra.tscn`.
##
## Funciona para qualquer Cifra (César ou Vigenère) porque cada uma sabe
## produzir seus próprios símbolos de chave por posição
## (`Cifra.simbolos_de_chave`) -- este arquivo não sabe qual algoritmo está
## por trás.

class Linha:
	extends RefCounted
	var claro: String = ""
	var chave: String = ""   # "" onde a posição não desloca (símbolo vazio)
	var cifrado: String = ""


static func montar(texto_claro: String, chave: String, cifra: Cifra) -> Array[Linha]:
	var cifrado: String = cifra.cifrar(texto_claro, chave)
	var simbolos: Array[String] = cifra.simbolos_de_chave(texto_claro, chave)

	var linhas: Array[Linha] = []
	for i: int in texto_claro.length():
		var linha := Linha.new()
		linha.claro = texto_claro[i]
		linha.chave = simbolos[i] if i < simbolos.size() else ""
		linha.cifrado = cifrado[i] if i < cifrado.length() else ""
		linhas.append(linha)
	return linhas
