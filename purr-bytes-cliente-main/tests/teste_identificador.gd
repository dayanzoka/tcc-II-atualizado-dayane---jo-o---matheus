extends CasoDeTeste

## UUID v4 gerado no cliente e a base da idempotencia do reenvio (restricao 3 da
## secao 4 do CLAUDE.md). Se o formato sair errado, o INSERT no PostgreSQL falha
## com o lote inteiro junto.


func teste_formato_canonico() -> void:
	var id: String = Identificador.uuid_v4()
	afirmar_tamanho(id, 36, "UUID tem 36 caracteres")
	afirmar_verdadeiro(Identificador.e_uuid(id), "UUID gerado passa na propria validacao")
	afirmar_igual(id, id.to_lower(), "UUID sai em minusculas (formato que o Postgres devolve)")


func teste_versao_e_variante() -> void:
	# RFC 4122: o 13o digito hexadecimal e a versao, o 17o e a variante.
	for i: int in 50:
		var id: String = Identificador.uuid_v4()
		afirmar_igual(id.substr(14, 1), "4", "digito de versao e 4")
		afirmar_verdadeiro("89ab".contains(id.substr(19, 1)),
			"digito de variante em [89ab], obtido %s" % id.substr(19, 1))


func teste_sem_colisao_em_lote() -> void:
	# Colisao aqui significaria duas sessoes com o mesmo id em uma sala de aula,
	# ou seja, dois participantes fundidos em um na analise.
	var vistos: Dictionary = {}
	var quantidade: int = 2000
	for i: int in quantidade:
		vistos[Identificador.uuid_v4()] = true
	afirmar_igual(vistos.size(), quantidade, "%d UUIDs distintos" % quantidade)


func teste_rejeita_formato_invalido() -> void:
	var invalidos: PackedStringArray = [
		"",
		"nao-e-uuid",
		"3AD7DDFA-46FE-4FD4-888F-BDAAC578C56E",          # maiusculas
		"3ad7ddfa46fe4fd4888fbdaac578c56e",              # sem hifens
		"3ad7ddfa-46fe-1fd4-888f-bdaac578c56e",          # versao 1
		"3ad7ddfa-46fe-4fd4-c88f-bdaac578c56e",          # variante invalida
		"3ad7ddfa-46fe-4fd4-888f-bdaac578c56e-extra",
	]
	for texto: String in invalidos:
		afirmar_falso(Identificador.e_uuid(texto), "rejeita '%s'" % texto)
