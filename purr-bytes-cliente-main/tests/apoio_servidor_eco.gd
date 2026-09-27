class_name ApoioServidorEco
extends RefCounted

## Apoio de teste para subir/derrubar tools/servidor_eco.py como processo real.
## NAO comeca com "teste_" de proposito: tests/runner.gd so carrega
## teste_*.gd como caso de teste, e este arquivo e infraestrutura compartilhada
## entre tests/teste_transporte_http.gd e tests/teste_resiliencia_http.gd, nao
## um arquivo de teste em si.
##
## Sobe o servidor Python como subprocesso de verdade (nao um mock): e assim
## que o Marco 3 valida TransporteHttp contra uma pilha de rede real, e mata-lo
## no meio de uma partida (Godot.parar) e a propria tecnica do teste de
## resiliencia -- ver docs/decisoes/0009-telemetria-http-e-resiliencia.md.

const CAMINHO_SCRIPT: String = "res://tools/servidor_eco.py"
const _INTERPRETE: String = "python"


## limpar=false preserva o log de uma execucao anterior -- usado pelo teste de
## resiliencia para religar o servidor na mesma porta SEM perder o historico
## de antes da queda (precisa contar tudo, de antes e depois, para provar
## "zero perdido, zero duplicado").
static func iniciar(porta: int, caminho_log: String, limpar: bool = true) -> int:
	var script_absoluto: String = ProjectSettings.globalize_path(CAMINHO_SCRIPT)
	var log_absoluto: String = ProjectSettings.globalize_path(caminho_log)
	if limpar and FileAccess.file_exists(caminho_log):
		DirAccess.remove_absolute(log_absoluto)

	var pid: int = OS.create_process(
		_INTERPRETE, [script_absoluto, str(porta), log_absoluto], false)
	return pid


## aguardar_pronto() manda uma requisicao de verdade para checar que o
## servidor esta ouvindo -- e essa requisicao TAMBEM fica no log do eco. Quem
## chama precisa limpar antes de começar a sessao real, senao a sonda vira
## o primeiro "registro recebido" por engano.
static func limpar_log(caminho_log: String) -> void:
	if FileAccess.file_exists(caminho_log):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_log))


static func parar(pid: int) -> void:
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)


## Tenta uma requisicao real ate o servidor aceitar conexao (o processo pode
## levar alguns quadros para comecar a ouvir a porta). Devolve false se
## esgotar as tentativas -- quem chama decide se isso e falha de teste ou nao.
static func aguardar_pronto(arvore: SceneTree, porta: int, tentativas: int = 40) -> bool:
	for i: int in tentativas:
		var http := HTTPRequest.new()
		arvore.root.add_child(http)
		var erro: Error = http.request(
			"http://127.0.0.1:%d/v1/sessoes" % porta,
			PackedStringArray(), HTTPClient.METHOD_POST, "{}")
		if erro == OK:
			var resposta: Array = await http.request_completed
			http.queue_free()
			if int(resposta[0]) == HTTPRequest.RESULT_SUCCESS:
				return true
		else:
			http.queue_free()
		await arvore.create_timer(0.05).timeout
	return false


## Le o log do servidor de eco (uma linha JSON por requisicao recebida).
static func ler_log(caminho_log: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if not FileAccess.file_exists(caminho_log):
		return saida
	var arquivo: FileAccess = FileAccess.open(caminho_log, FileAccess.READ)
	while not arquivo.eof_reached():
		var linha: String = arquivo.get_line().strip_edges()
		if linha.is_empty():
			continue
		var lido: Variant = JSON.parse_string(linha)
		if typeof(lido) == TYPE_DICTIONARY:
			saida.append(lido as Dictionary)
	arquivo.close()
	return saida
