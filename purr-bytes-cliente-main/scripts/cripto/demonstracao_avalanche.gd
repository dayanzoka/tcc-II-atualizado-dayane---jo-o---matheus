class_name DemonstracaoAvalanche
extends RefCounted

## Monta os dados do painel de efeito avalanche (CIFRA_DEMONSTRADA, Marco 3):
## dois textos quase iguais, seus digests SHA-256 lado a lado, com os
## dígitos hexadecimais que DIVERGEM marcados. Lógica pura, sem nó nenhum --
## mesmo padrão de scripts/cripto/demonstracao_cifra.gd (Marco 2).

class Coluna:
	extends RefCounted
	var digito_a: String = ""
	var digito_b: String = ""
	var diferente: bool = false


static func montar(texto_a: String, texto_b: String) -> Array[Coluna]:
	var digest_a: String = Sha256.digest_hex(texto_a)
	var digest_b: String = Sha256.digest_hex(texto_b)

	var colunas: Array[Coluna] = []
	for i: int in digest_a.length():
		var coluna := Coluna.new()
		coluna.digito_a = digest_a[i]
		coluna.digito_b = digest_b[i]
		coluna.diferente = digest_a[i] != digest_b[i]
		colunas.append(coluna)
	return colunas


## Proporção de dígitos que divergem entre os dois digests -- só para exibir
## um número junto do painel ("87% dos dígitos mudaram"), não usado para
## decidir nada.
static func proporcao_de_divergencia(colunas: Array[Coluna]) -> float:
	if colunas.is_empty():
		return 0.0
	var divergentes: int = 0
	for coluna: Coluna in colunas:
		if coluna.diferente:
			divergentes += 1
	return float(divergentes) / float(colunas.size())
