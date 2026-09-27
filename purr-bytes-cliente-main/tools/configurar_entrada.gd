extends SceneTree

## Gerador da secao [input] do project.godot.
##
## Rodar:
##   godot --headless --path . --script res://tools/configurar_entrada.gd
##
## Por que um gerador em vez de digitar a secao a mao: no project.godot as teclas
## sao codigos numericos crus (4194334 e F3, 4194320 e a seta para cima). Escrever
## isso a mao e um convite a erro silencioso -- o jogo simplesmente nao responde a
## uma tecla e ninguem descobre o porque. Aqui as teclas sao as constantes KEY_*
## da engine, e var_to_str() faz a serializacao no formato exato que o Godot le.
##
## O script IMPRIME o bloco em vez de chamar ProjectSettings.save(): salvar
## reescreveria o project.godot inteiro e apagaria os comentarios do arquivo.
## Copie a saida para a secao [input].
##
## physical_keycode e nao keycode: em teclado ABNT2 ou AZERTY o WASD continua nas
## mesmas teclas fisicas, que e o que importa para movimento.

const ACOES: Dictionary = {
	"mover_cima": [KEY_W, KEY_UP],
	"mover_baixo": [KEY_S, KEY_DOWN],
	"mover_esquerda": [KEY_A, KEY_LEFT],
	"mover_direita": [KEY_D, KEY_RIGHT],
	"abrir_terminal": [KEY_T, KEY_ENTER],
	"pausar": [KEY_ESCAPE],
	# Alterna a visualizacao do caminho do A*. Nao e depuracao descartavel: e a
	# demonstracao da IA para a banca (apontamento 7), entao tem tecla propria
	# desde o Marco 0.
	"alternar_depuracao": [KEY_F3],
	# Alterna o painel de demonstracao da cifra (CIFRA_DEMONSTRADA, Marco 2).
	# Mostra um exemplo FIXO (FaseConfig.texto/chave_exemplo_demonstracao), nao
	# o desafio corrente -- ver docs/decisoes/0008-vigenere-e-painel-de-demonstracao.md.
	"mostrar_demonstracao": [KEY_F4],
}


func _initialize() -> void:
	var linhas: PackedStringArray = PackedStringArray(["[input]", ""])

	for nome: String in ACOES:
		var eventos: Array = []
		for tecla: int in ACOES[nome] as Array:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			# InputEventKey.new() nasce com device = 16 no Godot 4.7, e o
			# InputMap so aceita evento de qualquer dispositivo quando device e
			# -1 (ALL_DEVICES). Sem esta linha as acoes existem, aparecem no
			# painel de InputMap do editor, e nenhuma tecla responde -- falha
			# sem mensagem de erro, que foi como o teste_entrada a pegou.
			evento.device = -1
			eventos.append(evento)

		var acao: Dictionary = {"deadzone": 0.2, "events": eventos}
		linhas.append("%s=%s" % [nome, var_to_str(acao)])
		linhas.append("")

	print("\n".join(linhas))
	quit(0)
