extends CasoDeTeste

## Vetores oficiais exigidos pelo criterio de aceite do Marco 3: o digest da
## string vazia e o de "abc" sao os canonicos (FIPS 180-4).


func teste_digest_da_string_vazia() -> void:
	afirmar_igual(Sha256.digest_hex(""),
		"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		"vetor oficial do digest de ''")


func teste_digest_de_abc() -> void:
	afirmar_igual(Sha256.digest_hex("abc"),
		"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
		"vetor oficial do digest de 'abc'")


func teste_digest_tem_64_caracteres_hexadecimais() -> void:
	var digest: String = Sha256.digest_hex("pacote")
	afirmar_tamanho(digest, 64, "SHA-256 produz 256 bits = 64 digitos hex")
	for i: int in digest.length():
		var c: String = digest[i]
		afirmar_verdadeiro((c >= "0" and c <= "9") or (c >= "a" and c <= "f"),
			"caractere '%s' na posicao %d e hexadecimal minusculo" % [c, i])


func teste_efeito_avalanche_um_caractere_muda_o_digest_inteiro() -> void:
	var digest_a: String = Sha256.digest_hex("mensagem")
	var digest_b: String = Sha256.digest_hex("mensagemm")
	afirmar_diferente(digest_a, digest_b, "textos diferentes produzem digests diferentes")

	var posicoes_iguais: int = 0
	for i: int in mini(digest_a.length(), digest_b.length()):
		if digest_a[i] == digest_b[i]:
			posicoes_iguais += 1
	# Nao e uma prova formal de avalanche (isso e propriedade criptografica do
	# algoritmo, nao algo que um teste unitario demonstra), so uma checagem de
	# sanidade: um hash de mao unica de verdade nao deixa a maioria dos
	# digitos parados no lugar so porque o texto quase nao mudou.
	afirmar_verdadeiro(posicoes_iguais < digest_a.length() / 2,
		"menos da metade dos digitos por acaso coincide entre os dois digests")


func teste_e_deterministico() -> void:
	afirmar_igual(Sha256.digest_hex("pacote"), Sha256.digest_hex("pacote"),
		"o mesmo texto sempre produz o mesmo digest")
