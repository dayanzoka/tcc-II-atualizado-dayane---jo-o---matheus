class_name CasoDeTeste
extends Node

## Base dos testes do projeto.
##
## Por que nao GUT nem gdUnit4: a regra da secao 2 do CLAUDE.md e usar a
## ferramenta nativa da engine e nao trazer addon para o nucleo. O Godot ja
## oferece tudo o que um runner precisa -- MainLoop scriptavel (extends
## SceneTree), reflexao (get_method_list), codigo de saida (quit(1)) e corrotina
## (await) -- entao a suite inteira sao dois arquivos sem dependencia externa,
## que rodam em qualquer maquina com o binario do Godot e nada mais.
##
## Convencao: cada arquivo tests/teste_*.gd estende CasoDeTeste e cada metodo
## teste_* e um teste. antes()/depois() rodam em volta de cada um. Metodo de
## teste pode ser corrotina (usar await livremente).

var _falhas: PackedStringArray = PackedStringArray()
var _verificacoes: int = 0

## Diretorio de trabalho dos testes. Fica em user:// e e limpo pelo runner, para
## nenhum teste tocar no config.cfg nem na fila de telemetria de verdade.
const DIR_TEMPORARIO: String = "user://testes"


func antes() -> void:
	pass


func depois() -> void:
	pass


func nome_do_caso() -> String:
	return get_script().resource_path.get_file().get_basename()


func falhas() -> PackedStringArray:
	return _falhas


func verificacoes() -> int:
	return _verificacoes


func limpar_resultado() -> void:
	_falhas = PackedStringArray()
	_verificacoes = 0


func caminho_temporario(nome: String) -> String:
	return "%s/%s" % [DIR_TEMPORARIO, nome]


# ---------------------------------------------------------------------------
# Verificacoes
# ---------------------------------------------------------------------------

func afirmar(condicao: bool, mensagem: String) -> bool:
	_verificacoes += 1
	if not condicao:
		_falhas.append(mensagem)
	return condicao


func afirmar_igual(obtido: Variant, esperado: Variant, mensagem: String) -> bool:
	return afirmar(_iguais(obtido, esperado),
		"%s -- esperado <%s>, obtido <%s>" % [mensagem, str(esperado), str(obtido)])


func afirmar_diferente(obtido: Variant, indesejado: Variant, mensagem: String) -> bool:
	return afirmar(not _iguais(obtido, indesejado),
		"%s -- nao deveria ser <%s>" % [mensagem, str(indesejado)])


func afirmar_verdadeiro(valor: bool, mensagem: String) -> bool:
	return afirmar(valor, "%s -- esperado verdadeiro" % mensagem)


func afirmar_falso(valor: bool, mensagem: String) -> bool:
	return afirmar(not valor, "%s -- esperado falso" % mensagem)


func afirmar_nulo(valor: Variant, mensagem: String) -> bool:
	return afirmar(valor == null, "%s -- esperado null, obtido <%s>" % [mensagem, str(valor)])


func afirmar_nao_nulo(valor: Variant, mensagem: String) -> bool:
	return afirmar(valor != null, "%s -- nao deveria ser null" % mensagem)


func afirmar_contem(texto: String, trecho: String, mensagem: String) -> bool:
	return afirmar(texto.contains(trecho),
		"%s -- <%s> nao contem <%s>" % [mensagem, texto, trecho])


func afirmar_tamanho(colecao: Variant, esperado: int, mensagem: String) -> bool:
	var tamanho: int = -1
	match typeof(colecao):
		TYPE_ARRAY:
			tamanho = (colecao as Array).size()
		TYPE_DICTIONARY:
			tamanho = (colecao as Dictionary).size()
		TYPE_PACKED_STRING_ARRAY:
			tamanho = (colecao as PackedStringArray).size()
		TYPE_STRING:
			tamanho = (colecao as String).length()
		_:
			return afirmar(false, "%s -- tipo sem tamanho" % mensagem)
	return afirmar(tamanho == esperado,
		"%s -- esperado tamanho %d, obtido %d" % [mensagem, esperado, tamanho])


func afirmar_proximo(obtido: float, esperado: float, tolerancia: float, mensagem: String) -> bool:
	return afirmar(absf(obtido - esperado) <= tolerancia,
		"%s -- esperado %f +- %f, obtido %f" % [mensagem, esperado, tolerancia, obtido])


func falhar(mensagem: String) -> void:
	afirmar(false, mensagem)


func _iguais(a: Variant, b: Variant) -> bool:
	# Comparacao de Dictionary e Array por conteudo: em GDScript, == entre
	# dicionarios ja compara valor a valor, mas explicitar evita surpresa se
	# algum dia um dos lados vier tipado.
	if typeof(a) != typeof(b):
		return str(a) == str(b)
	return a == b
