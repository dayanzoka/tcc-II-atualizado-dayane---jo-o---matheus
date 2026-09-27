class_name CifraVigenere
extends Cifra

## Cifra de Vigenère: a chave é alfabética e se repete ao longo do texto, em
## vez de um deslocamento único como César. É essa variação posição a posição
## que a fase 2 ensina -- e é o que torna a análise de frequência clássica
## ineficaz (a mesma letra do texto claro pode virar letras diferentes no
## cifrado, dependendo de qual letra da chave caiu ali).
##
## Só 'a'..'z' desloca e só letras avançam o índice da chave -- um espaço ou
## dígito no meio do texto não "gasta" uma posição da chave, senão a mesma
## palavra digitada com espaços diferentes cifraria diferente.

const _TAMANHO_ALFABETO: int = 26
const _CODIGO_A: int = 97  # 'a' em UTF-8/ASCII


func cifrar(texto: String, chave: String) -> String:
	return _aplicar(texto, chave, 1)


func decifrar(texto: String, chave: String) -> String:
	return _aplicar(texto, chave, -1)


func chave_sintaticamente_valida(chave: String) -> bool:
	if chave.is_empty():
		return false
	for i: int in chave.length():
		if not _e_letra(chave[i]):
			return false
	return true


## Para Vigenère, "faixa" (FaseConfig.faixa_chave_minima/maxima) não descreve
## um valor numérico -- descreve o COMPRIMENTO aceitável da chave. É a mesma
## leitura que ResolvedorComando usa via este método polimórfico, sem o
## resolvedor precisar saber qual algoritmo está em jogo (docs/decisoes/0008).
func dentro_da_faixa(chave: String, minimo: int, maximo: int) -> bool:
	return chave.length() >= minimo and chave.length() <= maximo


## Um símbolo de chave por posição do texto claro, para o painel de
## demonstração (scripts/cripto/demonstracao_cifra.gd): a letra da chave que
## se repete naquela posição, ou "" onde o texto claro não desloca nada.
func simbolos_de_chave(texto_claro: String, chave: String) -> Array[String]:
	var simbolos: Array[String] = []
	if chave.is_empty():
		for i: int in texto_claro.length():
			simbolos.append("")
		return simbolos

	var indice_chave: int = 0
	for i: int in texto_claro.length():
		if _e_letra(texto_claro[i]):
			simbolos.append(chave[indice_chave % chave.length()])
			indice_chave += 1
		else:
			simbolos.append("")
	return simbolos


func _aplicar(texto: String, chave: String, sinal: int) -> String:
	if chave.is_empty():
		return texto

	var resultado: String = ""
	var indice_chave: int = 0
	for i: int in texto.length():
		var caractere: String = texto[i]
		if _e_letra(caractere):
			var deslocamento: int = chave.unicode_at(indice_chave % chave.length()) - _CODIGO_A
			var posicao: int = caractere.unicode_at(0) - _CODIGO_A
			var nova: int = ((posicao + sinal * deslocamento) % _TAMANHO_ALFABETO + _TAMANHO_ALFABETO) \
				% _TAMANHO_ALFABETO
			resultado += char(_CODIGO_A + nova)
			indice_chave += 1
		else:
			resultado += caractere
	return resultado


func _e_letra(caractere: String) -> bool:
	return caractere >= "a" and caractere <= "z"
