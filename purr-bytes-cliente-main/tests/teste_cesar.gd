extends CasoDeTeste

## Vetores conhecidos exigidos pelo criterio de aceite do Marco 1: wrap-around,
## preservacao de nao-letras, chave 0 e chave 26.

var _cesar: CifraCesar


func antes() -> void:
	_cesar = CifraCesar.new()


func teste_deslocamento_simples() -> void:
	afirmar_igual(_cesar.cifrar("abc", "3"), "def", "deslocamento de 3 sem wrap")


func teste_wrap_around_no_fim_do_alfabeto() -> void:
	afirmar_igual(_cesar.cifrar("z", "3"), "c", "'z' + 3 volta para 'c'")
	afirmar_igual(_cesar.cifrar("xyz", "3"), "abc", "wrap-around em varias letras seguidas")


func teste_preserva_nao_letras() -> void:
	afirmar_igual(_cesar.cifrar("a b, c!", "3"), "d e, f!",
		"espaco, virgula e exclamacao atravessam sem alteracao")
	afirmar_igual(_cesar.cifrar("pacote_123", "1"), "qbdpuf_123",
		"digito e underscore nao sao deslocados")


func teste_chave_zero_e_identidade() -> void:
	afirmar_igual(_cesar.cifrar("pacote", "0"), "pacote", "chave 0 nao move nada")


func teste_chave_26_e_identidade_por_wrap_completo() -> void:
	afirmar_igual(_cesar.cifrar("pacote", "26"), "pacote",
		"26 e uma volta completa no alfabeto de 26 letras -- equivale a chave 0")


func teste_decifrar_desfaz_cifrar() -> void:
	for chave: String in ["0", "1", "13", "25", "26"]:
		var original: String = "o pacote atravessa o labirinto"
		var cifrado: String = _cesar.cifrar(original, chave)
		afirmar_igual(_cesar.decifrar(cifrado, chave), original,
			"decifrar com chave %s desfaz cifrar" % chave)


func teste_chave_valida_aceita_so_inteiros() -> void:
	afirmar_verdadeiro(_cesar.chave_sintaticamente_valida("3"), "'3' e um inteiro valido")
	afirmar_verdadeiro(_cesar.chave_sintaticamente_valida("0"), "'0' e valido")
	afirmar_falso(_cesar.chave_sintaticamente_valida("gato"), "'gato' nao e inteiro")
	afirmar_falso(_cesar.chave_sintaticamente_valida(""), "vazio nao e inteiro")
