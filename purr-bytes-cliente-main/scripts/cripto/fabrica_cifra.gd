class_name FabricaCifra
extends RefCounted

## Ponto único de dispatch "nome do algoritmo -> instância de Cifra".
##
## Usado por ResolvedorComando (validar/aplicar a cifra do desafio) e por
## FaseBase/PainelCifra (painel de demonstração) -- os dois precisam da mesma
## resposta para o mesmo FaseConfig.algoritmo, então o dispatch mora num só
## lugar. Adicionar SHA256/AES (Marco 3+) é um `match` novo aqui, nada além
## disso -- exatamente o "baixo esforço de codificação" da seção 1.

static func para_algoritmo(algoritmo: String) -> Cifra:
	match algoritmo:
		"CESAR":
			return CifraCesar.new()
		"VIGENERE":
			return CifraVigenere.new()
	return null  # SHA256/AES (Marco 3+): ainda nao ha Cifra para eles
