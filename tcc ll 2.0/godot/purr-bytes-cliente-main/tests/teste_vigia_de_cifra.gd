extends CasoDeTeste

## Vigia de CIFRA nas fases de autoria.
##
## Desde que as fases fixas sairam (ADR 0012), o editor so criava vigias de
## comando livre, comparados como texto. As cifras, o analisador
## lexico-sintatico e o painel de demonstracao ficaram sem nenhuma fase que os
## usasse -- e o TC-03 da monografia ("o analisador valida 'cifrar' e o
## personagem passa ileso") deixou de ser demonstravel. Estes testes travam a
## volta: vigia de cifra -> desafio -> AFD + parser + cifra real -> protecao.

var _fase: FaseBase = null
var _tentativas: Array[Dictionary] = []


func antes() -> void:
	Telemetria.reiniciar(TransporteMock.new(caminho_temporario("vigia_cifra.jsonl")),
		caminho_temporario("vigia_cifra_fila.json"))
	Sessao.iniciar()
	_tentativas.clear()
	Telemetria.tentativa_registrada.connect(_ao_registrar_tentativa)


func depois() -> void:
	Telemetria.tentativa_registrada.disconnect(_ao_registrar_tentativa)
	get_tree().paused = false
	if _fase != null and is_instance_valid(_fase):
		_fase.queue_free()
	_fase = null
	if Sessao.ativa:
		Sessao.encerrar()
	await get_tree().process_frame


func _ao_registrar_tentativa(tentativa: Dictionary) -> void:
	_tentativas.append(tentativa)


func _fase_com_vigias(vigias: Array) -> CarregadorFaseJson.Resultado:
	return CarregadorFaseJson.de_texto(JSON.stringify({
		"titulo": "fase de cifra",
		"mapa": {"largura": 21, "altura": 15, "seed": 777},
		"cachorros": vigias,
		"terminais": [{"enunciado": "?", "opcoes": ["a", "b"], "correta": "a"}],
	}))


func _vigia(algoritmo: String, palavra: String, chave: String = "") -> Dictionary:
	return {"cor": "#7ee081", "modo_de_bloqueio": "CIFRA", "algoritmo_exigido": algoritmo,
		"palavra": palavra, "chave": chave}


# ---------------------------------------------------------------------------
# JSON -> desafio
# ---------------------------------------------------------------------------

func teste_vigia_de_cesar_vira_desafio_do_terminal() -> void:
	var lido: CarregadorFaseJson.Resultado = _fase_com_vigias([_vigia("CESAR", "senha", "3")])
	if not afirmar_verdadeiro(lido.ok(), "fase com vigia de Cesar carrega: %s" % lido.mensagem()):
		return
	var config: FaseConfig = lido.config
	afirmar_tamanho(config.desafios, 1, "um desafio por vigia de cifra")
	var desafio: DesafioConfig = config.desafios[0]
	afirmar_igual(desafio.verbo_esperado, "cifrar", "o desafio espera 'cifrar'")
	afirmar_igual(desafio.chave_esperada, "3", "com a chave do vigia")
	afirmar_igual(desafio.texto_claro, "senha", "e a palavra do vigia")
	afirmar_igual(config.algoritmo, "CESAR", "a fase passa a falar o algoritmo do vigia")
	afirmar_igual(config.texto_exemplo_demonstracao, "senha", "o painel F4 ganha exemplo")
	afirmar_tamanho(config.problemas(), 0, "e a fase passa na validacao de justica")
	afirmar_igual(config.cachorros[0].comando_da_cifra(), "cifrar senha chave=3",
		"a legenda mostra o comando exato")


func teste_vigenere_e_sha256_tambem_viram_desafio() -> void:
	var lido: CarregadorFaseJson.Resultado = _fase_com_vigias([
		_vigia("VIGENERE", "pacote", "gato"), _vigia("SHA256", "pacote")])
	if not afirmar_verdadeiro(lido.ok(), "carrega: %s" % lido.mensagem()):
		return
	afirmar_tamanho(lido.config.desafios, 2, "um desafio por vigia")
	afirmar_igual(lido.config.desafios[0].chave_esperada, "gato", "Vigenere com chave em palavra")
	var sha: DesafioConfig = lido.config.desafios[1]
	afirmar_igual(sha.verbo_esperado, "verificar", "SHA-256 se resolve com 'verificar'")
	afirmar_igual(sha.resposta_esperada, Sha256.digest_hex("pacote").substr(0, 8),
		"a resposta e o prefixo do digest real (HashingContext)")


func teste_palavra_e_chave_invalidas_sao_recusadas_com_mensagem() -> void:
	var casos: Array[Dictionary] = [
		{"vigia": _vigia("CESAR", "", "3"), "motivo": "palavra vazia"},
		{"vigia": _vigia("CESAR", "3senha", "3"), "motivo": "palavra comecando com numero"},
		{"vigia": _vigia("CESAR", "hash", "3"), "motivo": "palavra reservada (verbo)"},
		{"vigia": _vigia("CESAR", "senha", "30"), "motivo": "chave de Cesar fora de 1..25"},
		{"vigia": _vigia("CESAR", "senha", "abc"), "motivo": "chave de Cesar nao numerica"},
		{"vigia": _vigia("VIGENERE", "senha", "g4to"), "motivo": "chave de Vigenere com numero"},
	]
	for caso: Dictionary in casos:
		var lido: CarregadorFaseJson.Resultado = _fase_com_vigias([caso["vigia"]])
		afirmar_falso(lido.ok(), "recusa: %s" % caso["motivo"])


func teste_vigia_de_cifra_faz_ida_e_volta_no_json() -> void:
	var original: CarregadorFaseJson.Resultado = _fase_com_vigias([_vigia("VIGENERE", "pacote", "gato")])
	var texto: String = JSON.stringify(CarregadorFaseJson.para_dicionario(original.config))
	var relido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(texto)
	afirmar_verdadeiro(relido.ok(), "relido")
	var cachorro: CachorroConfig = relido.config.cachorros[0]
	afirmar_igual(cachorro.modo_de_bloqueio, "CIFRA", "modo preservado")
	afirmar_igual(cachorro.algoritmo_exigido, "VIGENERE", "algoritmo preservado")
	afirmar_igual(cachorro.palavra_da_cifra, "pacote", "palavra preservada")
	afirmar_igual(cachorro.chave_da_cifra, "gato", "chave preservada")


# ---------------------------------------------------------------------------
# Em jogo: TC-03 e TC-04 na fase de exemplo
# ---------------------------------------------------------------------------

func _jogar_exemplo() -> FaseBase:
	var lido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		JSON.stringify(CarregadorFaseJson._exemplo()))
	_fase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame
	return _fase


func _vigia_de_cesar(fase: FaseBase) -> Cachorro:
	for alvo: Cachorro in fase.cachorros:
		if not alvo.bloqueia_por_comando() and not fase._apenas_persegue(alvo):
			return alvo
	return null


func teste_tc03_cifrar_passa_pelo_analisador_e_protege_do_vigia_de_cesar() -> void:
	var fase: FaseBase = await _jogar_exemplo()
	var verde: Cachorro = _vigia_de_cesar(fase)
	if not afirmar_nao_nulo(verde, "a fase de exemplo tem um vigia de cifra de Cesar"):
		return
	afirmar_falso(fase._protegido_contra(verde), "em texto claro, o vigia intercepta (TC-02)")

	fase._ao_submeter_comando("cifrar senha chave=3", 1200)

	afirmar_verdadeiro(fase.jogador.protecao_ativa, "o comando validado ativa a protecao")
	afirmar_igual(fase.jogador.algoritmo_protegido, "CESAR", "protecao de Cesar, pela cifra real")
	afirmar_verdadeiro(fase._protegido_contra(verde), "TC-03: o vigia de Cesar deixa passar")
	if afirmar_tamanho(_tentativas, 1, "uma tentativa_comando registrada"):
		var tentativa: Dictionary = _tentativas[0]
		afirmar_igual(tentativa["resultado"], CatalogoResultados.SUCESSO, "resultado SUCESSO")
		var tokens: Array = tentativa["tokens"] as Array
		afirmar_igual(tokens.size(), 6,
			"os tokens do AFD vao para a telemetria: cifrar senha chave = 3 EOF")
		afirmar_igual(String((tokens[0] as Dictionary)["tipo"]), "VERBO", "e o primeiro e o VERBO")


func teste_tc04_cyfrar_e_rejeitado_e_nao_protege() -> void:
	var fase: FaseBase = await _jogar_exemplo()
	var verde: Cachorro = _vigia_de_cesar(fase)

	fase._ao_submeter_comando("cyfrar senha chave=3", 900)

	afirmar_falso(fase.jogador.protecao_ativa, "TC-04: status de texto claro mantido")
	afirmar_falso(fase._protegido_contra(verde), "o vigia continua interceptando")
	if afirmar_tamanho(_tentativas, 1, "a falha tambem e registrada"):
		afirmar_igual(_tentativas[0]["resultado"], CatalogoResultados.ERRO_SINTATICO,
			"registro de erro de sintaxe, como no Quadro 1 da monografia")


func teste_chave_errada_e_erro_semantico() -> void:
	var fase: FaseBase = await _jogar_exemplo()
	fase._ao_submeter_comando("cifrar senha chave=4", 900)
	afirmar_falso(fase.jogador.protecao_ativa, "chave errada nao protege")
	afirmar_igual(_tentativas[0]["resultado"], CatalogoResultados.ERRO_SEMANTICO,
		"lexico e sintatico passam; a validacao semantica recusa")


func teste_dois_vigias_de_cifra_aceitam_qualquer_ordem() -> void:
	var lido: CarregadorFaseJson.Resultado = _fase_com_vigias([
		_vigia("CESAR", "senha", "3"), _vigia("VIGENERE", "pacote", "gato")])
	_fase = IniciadorDeFase.jogar(get_tree(), lido.config)
	await get_tree().process_frame

	# O jogador digita o comando do SEGUNDO vigia primeiro.
	_fase._ao_submeter_comando("cifrar pacote chave=gato", 1000)
	afirmar_igual(_fase.jogador.algoritmo_protegido, "VIGENERE",
		"o terminal reconhece o desafio pelo comando, nao pela fila")
