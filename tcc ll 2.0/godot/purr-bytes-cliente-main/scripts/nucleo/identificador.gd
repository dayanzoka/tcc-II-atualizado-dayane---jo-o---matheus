class_name Identificador
extends RefCounted

## Geracao de UUID v4 no cliente.
##
## Restricao 3 da secao 4 do CLAUDE.md: id_sessao, id_evento e id_tentativa sao
## gerados aqui, nunca pelo servidor. E isso que torna o reenvio de um lote
## idempotente -- o servidor reconhece os IDs repetidos e ignora as duplicatas.
##
## A aleatoriedade vem de Crypto.generate_random_bytes(), CSPRNG nativo, e nao
## de randi(): um gerador previsivel produziria colisao de id_sessao entre duas
## maquinas iniciadas ao mesmo tempo na mesma sala de aula.

const _BYTES_UUID: int = 16

static var _crypto: Crypto = null


static func uuid_v4() -> String:
	if _crypto == null:
		_crypto = Crypto.new()
	var b: PackedByteArray = _crypto.generate_random_bytes(_BYTES_UUID)

	# Campos de versao e variante exigidos pela RFC 4122.
	b[6] = (b[6] & 0x0F) | 0x40  # versao 4
	b[8] = (b[8] & 0x3F) | 0x80  # variante RFC 4122

	var hex: String = ""
	for i: int in _BYTES_UUID:
		hex += "%02x" % b[i]

	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]


## Aceita apenas o formato canonico 8-4-4-4-12 em minusculas, que e o que a
## coluna UUID do PostgreSQL vai receber.
static func e_uuid(texto: String) -> bool:
	var expressao := RegEx.create_from_string(
		"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
	)
	return expressao.search(texto) != null
