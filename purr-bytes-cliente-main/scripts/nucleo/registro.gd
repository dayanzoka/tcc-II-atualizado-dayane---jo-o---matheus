class_name Registro
extends RefCounted

## Log com nivel configuravel.
##
## Existe para atender ao criterio de aceite "nenhum print() solto": todo o
## projeto escreve por aqui, e o nivel vem do config.cfg. Erros e avisos usam
## push_error/push_warning -- funcoes nativas da engine -- porque elas aparecem
## no painel Depurador do editor e no stderr do processo headless, o que o
## print() nao faz.
##
## PROIBIDO passar a chave de API, id_sujeito bruto ou texto digitado pelo
## jogador sem truncar para qualquer funcao deste arquivo (ver secao 4 do
## CLAUDE.md). Log vira arquivo, arquivo vira anexo de monografia.

enum Nivel {
	SILENCIO = 0,
	ERRO = 1,
	AVISO = 2,
	INFO = 3,
	DEPURACAO = 4,
}

## Nivel corrente. E static para nao depender de autoload: os testes headless e
## o proprio ConfigJogo escrevem aqui antes de qualquer no existir.
static var nivel: Nivel = Nivel.INFO

static func definir_nivel_por_nome(nome: String) -> void:
	var normalizado: String = nome.strip_edges().to_upper()
	if not Nivel.has(normalizado):
		push_warning("[Registro] nivel de log desconhecido: %s" % normalizado)
		return
	nivel = Nivel[normalizado] as Nivel


static func nome_do_nivel() -> String:
	return Nivel.find_key(nivel) as String


static func erro(origem: String, mensagem: String) -> void:
	if nivel >= Nivel.ERRO:
		push_error(_formatar("ERRO", origem, mensagem))


static func aviso(origem: String, mensagem: String) -> void:
	if nivel >= Nivel.AVISO:
		push_warning(_formatar("AVISO", origem, mensagem))


static func info(origem: String, mensagem: String) -> void:
	if nivel >= Nivel.INFO:
		print(_formatar("INFO", origem, mensagem))


static func depuracao(origem: String, mensagem: String) -> void:
	if nivel >= Nivel.DEPURACAO:
		print(_formatar("DEPURACAO", origem, mensagem))


static func _formatar(rotulo: String, origem: String, mensagem: String) -> String:
	# Hora local aqui e proposital: este texto e para o desenvolvedor ler no
	# terminal. O relogio que vai para a telemetria e sempre UTC (secao 4.4).
	return "%s [%s] %s: %s" % [
		Time.get_time_string_from_system(false),
		rotulo,
		origem,
		mensagem,
	]
