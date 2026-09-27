extends CasoDeTeste

## Vetores conhecidos exigidos pelo criterio de aceite do Marco 2: chave mais
## curta que o texto (repete) e chave com caractere invalido.

var _vigenere: CifraVigenere


func antes() -> void:
	_vigenere = CifraVigenere.new()


func teste_vetor_classico() -> void:
	# Vetor de referencia (Vigenere classico): "attackatdawn" + chave "lemon".
	afirmar_igual(_vigenere.cifrar("attackatdawn", "lemon"), "lxfopvefrnhr",
		"vetor classico da cifra de Vigenere")


func teste_chave_mais_curta_que_o_texto_repete() -> void:
	afirmar_igual(_vigenere.cifrar("pacotededados", "ab"),
		_vigenere.cifrar("pacotededados", "ababababababa"),
		"chave curta repetida e chave longa ja repetida cifram igual")


func teste_preserva_nao_letras_sem_gastar_posicao_da_chave() -> void:
	afirmar_igual(_vigenere.cifrar("a b", "ab"), "a c",
		"espaco atravessa sem deslocar e sem avancar a chave -- "
		+ "a segunda letra usa a 2a posicao da chave ('b'), nao a 3a")


func teste_decifrar_desfaz_cifrar() -> void:
	for chave: String in ["a", "gato", "chaveextensadeteste"]:
		var original: String = "o pacote atravessa o labirinto"
		var cifrado: String = _vigenere.cifrar(original, chave)
		afirmar_igual(_vigenere.decifrar(cifrado, chave), original,
			"decifrar com chave '%s' desfaz cifrar" % chave)


func teste_chave_valida_aceita_so_letras_minusculas() -> void:
	afirmar_verdadeiro(_vigenere.chave_sintaticamente_valida("gato"), "'gato' e valida")
	afirmar_falso(_vigenere.chave_sintaticamente_valida("Gato"), "maiuscula invalida (ja normalizado antes)")
	afirmar_falso(_vigenere.chave_sintaticamente_valida("gato3"), "digito no meio invalida")
	afirmar_falso(_vigenere.chave_sintaticamente_valida(""), "vazio invalida")


func teste_faixa_e_comprimento_da_chave_nao_valor() -> void:
	afirmar_verdadeiro(_vigenere.dentro_da_faixa("gato", 3, 8), "4 letras esta entre 3 e 8")
	afirmar_falso(_vigenere.dentro_da_faixa("ab", 3, 8), "2 letras esta abaixo do minimo")
	afirmar_falso(_vigenere.dentro_da_faixa("umachavemuitograndeaqui", 3, 8), "acima do maximo")


func teste_simbolos_de_chave_avancam_so_em_letras() -> void:
	var simbolos: Array[String] = _vigenere.simbolos_de_chave("a b", "xy")
	afirmar_igual(simbolos, ["x", "", "y"], "espaco fica sem simbolo, chave nao pula posicao")
