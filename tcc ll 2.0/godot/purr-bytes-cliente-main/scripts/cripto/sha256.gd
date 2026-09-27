class_name Sha256
extends RefCounted

## Wrapper fino sobre HashingContext (HASH_SHA256) -- ferramenta nativa da
## secao 2 do CLAUDE.md. Hash NAO e implementado a mao, ao contrario de Cesar
## e Vigenere: a licao da fase 3 e que hash e de mao unica, e a unica forma
## honesta de mostrar isso e usar uma implementacao de verdade, nao uma
## reimplementacao amadora que o jogador poderia desconfiar que "tem um jeito
## de reverter".
##
## Nao herda de Cifra: hash nao cifra nem decifra, nao tem chave. E um
## utilitario a parte, usado pelos verbos "hash" e "verificar" (Marco 3).


static func digest_hex(texto: String) -> String:
	var contexto := HashingContext.new()
	contexto.start(HashingContext.HASH_SHA256)
	var bytes: PackedByteArray = texto.to_utf8_buffer()
	if not bytes.is_empty():
		# HashingContext.update() recusa buffer vazio (retorna FAILED) --
		# string vazia e um digest valido (o vetor oficial e exatamente esse
		# caso), so nao ha nada para alimentar no contexto antes de finish().
		contexto.update(bytes)
	return contexto.finish().hex_encode()
