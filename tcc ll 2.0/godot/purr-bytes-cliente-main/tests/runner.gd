extends SceneTree

## Runner da suite. Uso:
##   godot --headless --path . --script res://tests/runner.gd
##   godot --headless --path . --script res://tests/runner.gd -- teste_telemetria
##
## Sai com codigo 0 se tudo passou e 1 se algo falhou, o que e o suficiente para
## qualquer CI e para um "if ($?)" no PowerShell.
##
## Roda como MainLoop, entao os autoloads existem (ConfigJogo, Sessao,
## Telemetria) exatamente como no jogo -- e por isso os testes de telemetria
## precisam apontar o autoload para arquivos temporarios via configurar().

const DIRETORIO_TESTES: String = "res://tests"
const PREFIXO_ARQUIVO: String = "teste_"
const PREFIXO_METODO: String = "teste_"


func _initialize() -> void:
	# Sem isso a saida da suite vira um muro de INFO da propria telemetria.
	Registro.definir_nivel_por_nome("ERRO")
	_executar()


func _executar() -> void:
	await process_frame

	_preparar_diretorio_temporario()

	var filtro: String = _filtro_da_linha_de_comando()
	var arquivos: PackedStringArray = _arquivos_de_teste(filtro)
	if arquivos.is_empty():
		print("nenhum arquivo de teste encontrado (filtro: '%s')" % filtro)
		quit(1)
		return

	var total_testes: int = 0
	var total_verificacoes: int = 0
	var falhas: PackedStringArray = PackedStringArray()

	print("== suite Purr Bytes -- %d arquivo(s) ==" % arquivos.size())

	for caminho: String in arquivos:
		var script: GDScript = load(caminho) as GDScript
		if script == null:
			falhas.append("%s: nao carregou como GDScript" % caminho)
			continue

		var caso: CasoDeTeste = script.new() as CasoDeTeste
		if caso == null:
			falhas.append("%s: raiz nao estende CasoDeTeste" % caminho)
			continue

		root.add_child(caso)
		var nomes: PackedStringArray = _metodos_de_teste(caso)
		var falhas_do_arquivo: int = 0

		for nome: String in nomes:
			caso.limpar_resultado()
			total_testes += 1

			caso.antes()
			# await em call() dinamico: se o metodo for corrotina, espera; se
			# nao for, o valor volta na hora. E o que permite escrever teste
			# assincrono e sincrono no mesmo arquivo sem marcacao.
			await caso.call(nome)
			caso.depois()

			total_verificacoes += caso.verificacoes()
			for falha: String in caso.falhas():
				falhas_do_arquivo += 1
				falhas.append("%s::%s -- %s" % [caso.nome_do_caso(), nome, falha])

		var rotulo: String = "ok" if falhas_do_arquivo == 0 else "FALHOU"
		print("  [%s] %s (%d teste(s))" % [rotulo, caso.nome_do_caso(), nomes.size()])

		caso.queue_free()
		await process_frame

	print("")
	print("testes: %d | verificacoes: %d | falhas: %d"
		% [total_testes, total_verificacoes, falhas.size()])

	if falhas.is_empty():
		print("RESULTADO: verde")
		quit(0)
		return

	print("RESULTADO: vermelho")
	for falha: String in falhas:
		print("  - %s" % falha)
	quit(1)


func _filtro_da_linha_de_comando() -> String:
	for argumento: String in OS.get_cmdline_user_args():
		if not argumento.begins_with("-"):
			return argumento
	return ""


func _arquivos_de_teste(filtro: String) -> PackedStringArray:
	var encontrados := PackedStringArray()
	for nome: String in DirAccess.get_files_at(DIRETORIO_TESTES):
		# O editor pode deixar .gd.uid ao lado; comparar a extensao evita
		# tentar carregar esses arquivos como script.
		if not nome.begins_with(PREFIXO_ARQUIVO) or nome.get_extension() != "gd":
			continue
		if filtro != "" and not nome.contains(filtro):
			continue
		encontrados.append("%s/%s" % [DIRETORIO_TESTES, nome])
	encontrados.sort()
	return encontrados


## Reflexao nativa: descobre os metodos teste_* sem nenhum registro manual.
func _metodos_de_teste(caso: CasoDeTeste) -> PackedStringArray:
	var nomes := PackedStringArray()
	for metodo: Dictionary in caso.get_method_list():
		var nome: String = String(metodo["name"])
		if nome.begins_with(PREFIXO_METODO) and not nomes.has(nome):
			nomes.append(nome)
	nomes.sort()
	return nomes


func _preparar_diretorio_temporario() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	if dir.dir_exists(CasoDeTeste.DIR_TEMPORARIO):
		var interno: DirAccess = DirAccess.open(CasoDeTeste.DIR_TEMPORARIO)
		if interno != null:
			for arquivo: String in interno.get_files():
				interno.remove(arquivo)
	else:
		dir.make_dir_recursive(CasoDeTeste.DIR_TEMPORARIO)

	# Fases criadas pelos testes vivem aqui, nunca em user://fases: a lista de
	# fases do jogador nao pode herdar "Fase de teste" de uma suite interrompida.
	var pasta_de_fases: String = CasoDeTeste.DIR_TEMPORARIO.path_join("fases")
	var fases: DirAccess = DirAccess.open(pasta_de_fases)
	if fases != null:
		for arquivo: String in fases.get_files():
			fases.remove(arquivo)
	CarregadorFaseJson.pasta_das_fases = pasta_de_fases
