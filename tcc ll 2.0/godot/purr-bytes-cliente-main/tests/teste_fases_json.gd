extends CasoDeTeste

## Carga de fase por JSON e geracao de mapa (Etapa 1 da reconstrucao do editor).
##
## Duas garantias que estes testes existem para travar:
##   1. arquivo malformado NUNCA derruba o jogo -- volta erro legivel;
##   2. mapa gerado e SEMPRE solucionavel, porque passa pelo mesmo
##      MapaConfig.problemas() que a fase roda ao carregar.


func _json_valido(extra: Dictionary = {}) -> String:
	var base: Dictionary = {
		"titulo": "Fase de teste",
		"briefing": "atravesse a rede",
		"vidas": 3,
		"mapa": {"largura": 21, "altura": 15, "seed": 4242},
		"cachorros": [
			{"cor": "#40a9ff", "comando_para_bloquear": "trocar senha"},
			{"cor": "#ff6b6b", "comando_para_bloquear": ""},
		],
		"terminais": [
			{"enunciado": "o que e phishing?", "opcoes": ["mensagem que finge ser de quem nao e",
				"um tipo de cabo"], "correta": "mensagem que finge ser de quem nao e",
				"explicacao": "ele pesca a sua confianca."},
			{"enunciado": "senha boa e...", "opcoes": ["longa", "curta"], "correta": "longa",
				"explicacao": "tamanho vale mais que simbolo."},
		],
	}
	for chave: String in extra:
		base[chave] = extra[chave]
	return JSON.stringify(base)


# ---------------------------------------------------------------------------
# Gerador de mapa
# ---------------------------------------------------------------------------

func teste_mapa_gerado_e_sempre_solucionavel() -> void:
	# Varias sementes: um mapa valido por sorte nao provaria nada.
	for semente: int in [1, 7, 99, 1234, 20260914]:
		var resultado: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(21, 15, semente, 3, 2)
		if not afirmar_verdadeiro(resultado.ok(),
				"semente %d gera mapa (%s)" % [semente, " | ".join(resultado.erros)]):
			continue

		afirmar_igual(resultado.mapa.problemas().size(), 0,
			"semente %d: o mapa passa no validador do jogo" % semente)
		afirmar_igual(resultado.mapa.celulas_de(MapaConfig.PACOTE).size(), 3,
			"tres pacotes pedidos, tres marcados")
		afirmar_igual(resultado.mapa.celulas_de(MapaConfig.CACHORRO).size(), 2,
			"dois cachorros pedidos, dois marcados")


func teste_mesma_semente_gera_o_mesmo_mapa() -> void:
	var a: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(21, 15, 777, 3, 2)
	var b: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(21, 15, 777, 3, 2)
	afirmar_igual(a.mapa.linhas, b.mapa.linhas,
		"a mesma semente devolve o mesmo labirinto -- e o que faz a fase salva ser a fase jogada")


func teste_sementes_diferentes_geram_mapas_diferentes() -> void:
	var a: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(21, 15, 1, 3, 2)
	var b: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(21, 15, 2, 3, 2)
	afirmar_diferente(a.mapa.linhas, b.mapa.linhas, "sementes diferentes, mapas diferentes")


func teste_braiding_deixa_o_mapa_com_ciclos() -> void:
	var resultado: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(21, 15, 31337, 3, 2)
	var mapa: MapaConfig = resultado.mapa

	var livres: int = 0
	var becos: int = 0
	for y: int in mapa.altura():
		for x: int in mapa.largura():
			var celula := Vector2i(x, y)
			if not mapa.e_andavel(celula):
				continue
			livres += 1
			var vizinhos: int = 0
			for direcao: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				if mapa.e_andavel(celula + direcao):
					vizinhos += 1
			if vizinhos <= 1:
				becos += 1

	# Labirinto perfeito (sem braiding) tem muitos becos; com braiding sobram
	# poucos. Beco demais = quem foge fica encurralado, e a fuga vira sorte.
	afirmar_verdadeiro(float(becos) / float(livres) < 0.12,
		"poucos becos sem saida (%d de %d celulas livres): ha rotas alternativas" % [becos, livres])


func teste_area_pequena_demais_devolve_erro_em_vez_de_mapa_quebrado() -> void:
	var resultado: GeradorDeMapa.Resultado = GeradorDeMapa.gerar(9, 9, 5, 40, 40)
	afirmar_falso(resultado.ok(), "pedido impossivel nao devolve mapa")
	afirmar_verdadeiro(resultado.erros.size() >= 1, "e explica por que")


# ---------------------------------------------------------------------------
# Carga de JSON
# ---------------------------------------------------------------------------

func teste_json_valido_vira_fase_jogavel() -> void:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(_json_valido())

	if not afirmar_verdadeiro(resultado.ok(), "JSON valido carrega (%s)" % resultado.mensagem()):
		return

	var config: FaseConfig = resultado.config
	afirmar_igual(config.titulo, "Fase de teste", "titulo lido")
	afirmar_igual(config.vidas_iniciais, 3, "vidas lidas")
	afirmar_tamanho(config.cachorros, 2, "dois cachorros")
	afirmar_tamanho(config.pacotes, 2, "dois terminais viram dois pacotes")
	afirmar_igual(config.pacotes[0].resposta_correta, "mensagem que finge ser de quem nao e",
		"a resposta correta acompanha a pergunta")
	afirmar_nao_nulo(config.mapa, "o mapa foi gerado")
	afirmar_igual(config.problemas().size(), 0, "e a fase inteira passa no validador do jogo")


func teste_id_fase_e_gerado_quando_ausente_e_respeitado_quando_existe() -> void:
	var sem_id: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(_json_valido())
	afirmar_verdadeiro(Identificador.e_uuid(sem_id.config.id_fase),
		"JSON sem id_fase recebe um UUID valido na carga")

	var com_id: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		_json_valido({"id_fase": "11111111-2222-4333-8444-555555555555"}))
	afirmar_igual(com_id.config.id_fase, "11111111-2222-4333-8444-555555555555",
		"id_fase existente e preservado -- e a ligacao com a telemetria ja coletada")


func teste_cachorro_com_comando_vazio_so_persegue() -> void:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(_json_valido())
	afirmar_verdadeiro(resultado.config.cachorros[0].bloqueia_por_comando(),
		"cachorro com comando e bloqueavel")
	afirmar_falso(resultado.config.cachorros[1].bloqueia_por_comando(),
		"comando vazio = so persegue, e a unica defesa e a rota")


func teste_cor_do_json_vira_cor_do_cachorro() -> void:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(_json_valido())
	afirmar_igual(resultado.config.cachorros[0].cor_efetiva(), Color("#40a9ff"),
		"a cor escolhida no arquivo e a cor do cachorro")


func teste_json_malformado_devolve_erro_sem_travar() -> void:
	for texto: String in ["{ isso nao e json", "[]", "", "42"]:
		var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(texto)
		afirmar_falso(resultado.ok(), "texto invalido nao vira fase: %s" % texto.substr(0, 12))
		afirmar_verdadeiro(resultado.erros.size() >= 1, "e devolve mensagem legivel")


func teste_json_sem_titulo_e_recusado() -> void:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(
		_json_valido({"titulo": "   "}))
	afirmar_falso(resultado.ok(), "fase sem titulo nao carrega")
	afirmar_contem(resultado.mensagem(), "titulo", "a mensagem diz qual campo falta")


func teste_terminal_sem_resposta_entre_as_opcoes_e_recusado() -> void:
	var resultado: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(_json_valido({
		"terminais": [{"enunciado": "pergunta", "opcoes": ["a", "b"], "correta": "c"}],
	}))
	afirmar_falso(resultado.ok(), "resposta fora das opcoes reprova a fase")
	afirmar_contem(resultado.mensagem(), "resposta correta", "e explica o porque")


# ---------------------------------------------------------------------------
# Round-trip
# ---------------------------------------------------------------------------

func teste_round_trip_nao_perde_cachorro_nem_pergunta() -> void:
	var original: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(_json_valido())
	var texto: String = JSON.stringify(CarregadorFaseJson.para_dicionario(original.config))
	var relido: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(texto)

	if not afirmar_verdadeiro(relido.ok(), "o que sai do escritor volta pelo leitor (%s)"
			% relido.mensagem()):
		return

	afirmar_igual(relido.config.titulo, original.config.titulo, "titulo preservado")
	afirmar_igual(relido.config.id_fase, original.config.id_fase, "id_fase preservado")
	afirmar_tamanho(relido.config.cachorros, original.config.cachorros.size(),
		"nenhum cachorro se perde")
	afirmar_tamanho(relido.config.pacotes, original.config.pacotes.size(),
		"nenhuma pergunta se perde")
	afirmar_igual(relido.config.cachorros[0].comando_para_bloquear,
		original.config.cachorros[0].comando_para_bloquear, "o comando de bloqueio sobrevive")
	afirmar_igual(relido.config.mapa.linhas, original.config.mapa.linhas,
		"o labirinto e o MESMO: a semente viaja no arquivo")


func teste_nome_de_arquivo_e_sanitizado() -> void:
	afirmar_igual(CarregadorFaseJson.nome_de_arquivo("Senhas Fortes!"),
		CarregadorFaseJson.pasta_das_fases.path_join("senhas-fortes.json"),
		"titulo vira nome de arquivo seguro")
	afirmar_igual(CarregadorFaseJson.nome_de_arquivo("   "),
		CarregadorFaseJson.pasta_das_fases.path_join("fase.json"),
		"titulo vazio nao gera nome vazio")
