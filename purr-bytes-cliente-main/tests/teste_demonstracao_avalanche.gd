extends CasoDeTeste

## Alinhamento do painel de efeito avalanche -- lógica pura, sem UI.


func teste_64_colunas_uma_por_digito_hex() -> void:
	var colunas: Array[DemonstracaoAvalanche.Coluna] = DemonstracaoAvalanche.montar("mensagem", "mensagemm")
	afirmar_tamanho(colunas, 64, "SHA-256 tem 64 digitos hex, uma coluna cada")


func teste_marca_digitos_divergentes() -> void:
	var colunas: Array[DemonstracaoAvalanche.Coluna] = DemonstracaoAvalanche.montar("abc", "abd")
	var digest_a: String = Sha256.digest_hex("abc")
	var digest_b: String = Sha256.digest_hex("abd")

	for i: int in colunas.size():
		var esperado_diferente: bool = digest_a[i] != digest_b[i]
		afirmar_igual(colunas[i].diferente, esperado_diferente,
			"coluna %d marcada corretamente" % i)
		afirmar_igual(colunas[i].digito_a, digest_a[i], "digito A preservado")
		afirmar_igual(colunas[i].digito_b, digest_b[i], "digito B preservado")


func teste_textos_identicos_nao_divergem_em_nada() -> void:
	var colunas: Array[DemonstracaoAvalanche.Coluna] = DemonstracaoAvalanche.montar("pacote", "pacote")
	afirmar_igual(DemonstracaoAvalanche.proporcao_de_divergencia(colunas), 0.0,
		"mesmo texto produz o mesmo digest -- zero divergencia")


func teste_proporcao_de_divergencia_e_alta_para_efeito_avalanche() -> void:
	var colunas: Array[DemonstracaoAvalanche.Coluna] = DemonstracaoAvalanche.montar("mensagem", "mensagemm")
	afirmar_verdadeiro(DemonstracaoAvalanche.proporcao_de_divergencia(colunas) > 0.3,
		"um caractere a mais no texto muda uma fracao grande dos digitos do hash")
