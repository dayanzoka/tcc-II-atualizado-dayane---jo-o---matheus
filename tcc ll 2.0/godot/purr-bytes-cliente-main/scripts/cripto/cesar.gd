class_name CifraCesar
extends Cifra

## Cifra de deslocamento fixo (Cesar), implementada a mao.
##
## Diferente do SHA-256 do Marco 3, Cesar NAO esta na lista de "prefira a
## ferramenta nativa" da secao 2: e o proprio algoritmo que a fase 1 ensina, e
## a licao depende de o deslocamento aparecer explicito no codigo -- chamar uma
## biblioteca aqui esconderia exatamente o que a fase quer mostrar.
##
## So 'a'..'z' desloca; qualquer outro caractere (espaco, digito, pontuacao)
## atravessa sem alteracao. E o que "preservacao de nao-letras" quer dizer no
## criterio de aceite do Marco 1.

const _TAMANHO_ALFABETO: int = 26
const _CODIGO_A: int = 97  # 'a' em UTF-8/ASCII


func cifrar(texto: String, chave: String) -> String:
	return _deslocar(texto, _chave_para_inteiro(chave))


## Decifrar e cifrar com o deslocamento invertido -- Cesar e a propria inversa
## de si mesma trocando o sinal da chave, entao nao ha algoritmo separado aqui.
func decifrar(texto: String, chave: String) -> String:
	return _deslocar(texto, -_chave_para_inteiro(chave))


func chave_sintaticamente_valida(chave: String) -> bool:
	return chave.is_valid_int()


## Para Cesar, "faixa" e o VALOR da chave -- ver Cifra.dentro_da_faixa.
func dentro_da_faixa(chave: String, minimo: int, maximo: int) -> bool:
	var valor: int = int(chave)
	return valor >= minimo and valor <= maximo


## O mesmo deslocamento se repete em toda letra -- e a propria licao da fase
## (deslocamento FIXO, ao contrario de Vigenere).
func simbolos_de_chave(texto_claro: String, chave: String) -> Array[String]:
	var simbolos: Array[String] = []
	for i: int in texto_claro.length():
		var caractere: String = texto_claro[i]
		simbolos.append(chave if (caractere >= "a" and caractere <= "z") else "")
	return simbolos


func _chave_para_inteiro(chave: String) -> int:
	return int(chave)


func _deslocar(texto: String, deslocamento: int) -> String:
	# Chave 26 tem que se comportar como chave 0 (wrap-around completo), e uma
	# chave negativa (decifrar) tem que cair num deslocamento positivo antes do
	# modulo -- por isso soma _TAMANHO_ALFABETO antes do segundo '%'.
	var normalizado: int = ((deslocamento % _TAMANHO_ALFABETO) + _TAMANHO_ALFABETO) % _TAMANHO_ALFABETO

	var resultado: String = ""
	for i: int in texto.length():
		var codigo: int = texto.unicode_at(i)
		if codigo >= _CODIGO_A and codigo < _CODIGO_A + _TAMANHO_ALFABETO:
			var posicao: int = codigo - _CODIGO_A
			var deslocada: int = (posicao + normalizado) % _TAMANHO_ALFABETO
			resultado += char(_CODIGO_A + deslocada)
		else:
			resultado += texto[i]
	return resultado
