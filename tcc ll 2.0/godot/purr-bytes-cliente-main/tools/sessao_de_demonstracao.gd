extends SceneTree

## Sessao de demonstracao em modo MOCK, sem abrir janela.
##
##   godot --headless --path . --script res://tools/sessao_de_demonstracao.gd
##
## Para que serve:
##   1. verificar o criterio de aceite do Marco 0 em uma linha de comando --
##      abre e encerra uma sessao e mostra o .jsonl resultante;
##   2. gerar os exemplos de payload de docs/contrato-telemetria.md, que sao o
##      que o time do back-end vai usar para implementar as rotas;
##   3. demonstrar a coleta para a banca sem depender de servidor no ar.
##
## O roteiro fica em outro arquivo e e carregado em tempo de execucao porque um
## script passado em --script e compilado ANTES de os autoloads existirem: citar
## Telemetria aqui daria "Identifier not found" antes de o jogo comecar.

const ROTEIRO: String = "res://tools/roteiro_de_demonstracao.gd"


func _initialize() -> void:
	_executar()


func _executar() -> void:
	await process_frame
	var roteiro: RefCounted = load(ROTEIRO).new()
	# Chamada dinamica pelo mesmo motivo do comentario acima.
	await roteiro.call("executar")
	quit(0)
