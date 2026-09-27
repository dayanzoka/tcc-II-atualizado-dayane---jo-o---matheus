extends CasoDeTeste

## Telemetria independente de fase: a identidade viaja em `id_fase` (UUID) e
## nenhum registro e descartado por numero de fase.
##
## O bug que estes testes travam: o cliente nasceu contra um banco de quatro
## fases fixas (CHECK fase BETWEEN 1 AND 4) e DESCARTAVA a tentativa cujo numero
## caisse fora. Numa ferramenta em que fases sao criadas livremente, isso
## significaria perder o dado da maioria das fases -- o oposto do que a
## instrumentacao existe para fazer.

var _mock: TransporteMock


func antes() -> void:
	_mock = TransporteMock.new(caminho_temporario("global_mock.jsonl"))
	Telemetria.reiniciar(_mock, caminho_temporario("global_fila.json"))


func depois() -> void:
	if Sessao.ativa:
		Sessao.encerrar()


func teste_tentativa_de_fase_alta_nao_e_descartada() -> void:
	Sessao.iniciar()
	Sessao.entrar_na_fase(97, 3, "11111111-2222-4333-8444-555555555555", "fase criada pelo professor")

	# 97 esta muito fora de 1..4: antes, esta linha sumia com um erro no log.
	var tentativa: Dictionary = Telemetria.registrar_tentativa(
		97, "desafio-livre", "cifrar pacote chave=3", [],
		CatalogoResultados.SUCESSO, "", 1200, 1)

	afirmar_falso(tentativa.is_empty(), "a tentativa de uma fase fora de 1..4 e registrada")
	afirmar_igual(String(tentativa["id_fase"]), "11111111-2222-4333-8444-555555555555",
		"a identidade da fase viaja na tentativa")
	afirmar_igual(String(tentativa["titulo_fase"]), "fase criada pelo professor",
		"o titulo acompanha, para diagnostico legivel")
	afirmar_nulo(tentativa["fase"],
		"o numero legado vai null fora de 1..4, para nao violar o CHECK do banco atual")


func teste_evento_de_fase_alta_carrega_id_fase() -> void:
	Sessao.iniciar()
	Sessao.entrar_na_fase(42, 3, "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee", "outra fase")

	var evento: Dictionary = Telemetria.registrar_evento(
		CatalogoEventos.FASE_INICIADA, {"algoritmo": "CESAR"}, 42)

	afirmar_falso(evento.is_empty(), "o evento de uma fase fora de 1..4 e registrado")
	afirmar_igual(String(evento["id_fase"]), "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
		"id_fase presente no evento")
	afirmar_nulo(evento["fase"], "o numero legado vai null fora da faixa")


func teste_fase_de_1_a_4_continua_enviando_o_numero_legado() -> void:
	Sessao.iniciar()
	Sessao.entrar_na_fase(2, 3, "cccccccc-dddd-4eee-bfff-000000000000", "fase 2")

	var evento: Dictionary = Telemetria.registrar_evento(CatalogoEventos.FASE_INICIADA, {}, 2)
	afirmar_igual(int(evento["fase"]), 2,
		"dentro de 1..4 o numero continua indo: quem le o campo antigo nao quebra")


func teste_sessao_nao_limita_mais_a_fase_a_quatro() -> void:
	Sessao.iniciar()
	Sessao.entrar_na_fase(12, 3, "dddddddd-1111-4222-9333-444444444444", "decima segunda")

	afirmar_igual(Sessao.fase_atual, 12, "o numero da fase nao e mais grampeado em 4")
	afirmar_igual(Sessao.id_fase, "dddddddd-1111-4222-9333-444444444444", "a sessao guarda a identidade")

	Sessao.sair_da_fase()
	afirmar_igual(Sessao.id_fase, "", "sair da fase limpa a identidade")
	afirmar_igual(Sessao.titulo_fase, "", "e o titulo")


func teste_id_fase_e_estavel_e_anonimo_na_fase_de_exemplo() -> void:
	# O id_fase viaja DENTRO do JSON: carregar o mesmo arquivo duas vezes tem
	# que devolver a mesma identidade, senao a telemetria nao liga as sessoes.
	var texto: String = JSON.stringify(CarregadorFaseJson._exemplo())
	var primeira: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(texto)
	var segunda: CarregadorFaseJson.Resultado = CarregadorFaseJson.de_texto(texto)
	if not afirmar_verdadeiro(primeira.ok() and segunda.ok(), "fase de exemplo carrega"):
		return
	var config: FaseConfig = primeira.config
	afirmar_verdadeiro(Identificador.e_uuid(config.id_fase), "fase de exemplo tem id_fase UUID")
	afirmar_igual(segunda.config.id_fase, config.id_fase, "mesmo arquivo, mesmo id_fase")
	# Anonimato (RNF): id tecnico, nada de pessoal.
	afirmar_falso(config.id_fase.contains("@"), "id_fase nao carrega nada parecido com e-mail")
	afirmar_igual(config.garantir_id_fase(), config.id_fase,
		"garantir_id_fase() devolve o id gravado, sem trocar a identidade")


func teste_fase_sem_id_recebe_um_na_carga() -> void:
	var config := FaseConfig.new()
	config.titulo = "fase antiga sem id"
	afirmar_igual(config.id_fase, "", "recurso antigo nasce sem id")

	var nivel: String = Registro.nome_do_nivel()
	Registro.definir_nivel_por_nome("SILENCIO")  # garantir_id_fase avisa alto, de proposito
	var gerado: String = config.garantir_id_fase()
	Registro.definir_nivel_por_nome(nivel)

	afirmar_verdadeiro(Identificador.e_uuid(gerado), "a migracao suave gera um UUID valido")
	afirmar_igual(config.id_fase, gerado, "e grava no recurso em memoria")
