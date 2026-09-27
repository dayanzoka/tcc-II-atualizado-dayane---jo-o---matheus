extends CasoDeTeste

## Alinhamento letra a letra do painel de demonstração -- lógica pura, sem UI.


func teste_cesar_repete_o_mesmo_simbolo_em_toda_letra() -> void:
	var linhas: Array[DemonstracaoCifra.Linha] = DemonstracaoCifra.montar(
		"a b", "3", CifraCesar.new())
	afirmar_tamanho(linhas, 3, "uma linha por caractere, inclusive o espaco")
	afirmar_igual(linhas[0].claro, "a", "claro[0]")
	afirmar_igual(linhas[0].chave, "3", "cesar mostra a chave em toda posicao com letra")
	afirmar_igual(linhas[0].cifrado, "d", "cifrado[0]")
	afirmar_igual(linhas[1].claro, " ", "espaco preservado como linha propria")
	afirmar_igual(linhas[1].chave, "", "espaco nao tem simbolo de chave (nao desloca)")
	afirmar_igual(linhas[1].cifrado, " ", "espaco atravessa sem cifrar")
	afirmar_igual(linhas[2].chave, "3", "segunda letra tambem mostra a mesma chave")


func teste_vigenere_avanca_o_simbolo_por_letra() -> void:
	var linhas: Array[DemonstracaoCifra.Linha] = DemonstracaoCifra.montar(
		"ab", "xy", CifraVigenere.new())
	afirmar_igual(linhas[0].chave, "x", "primeira letra usa a 1a posicao da chave")
	afirmar_igual(linhas[1].chave, "y", "segunda letra usa a 2a posicao da chave")
	afirmar_igual(linhas[0].cifrado + linhas[1].cifrado, CifraVigenere.new().cifrar("ab", "xy"),
		"cifrado da demonstracao bate com a cifra real")


func teste_texto_vazio_produz_lista_vazia() -> void:
	var linhas: Array[DemonstracaoCifra.Linha] = DemonstracaoCifra.montar("", "3", CifraCesar.new())
	afirmar_tamanho(linhas, 0, "sem texto claro, sem linha nenhuma")
