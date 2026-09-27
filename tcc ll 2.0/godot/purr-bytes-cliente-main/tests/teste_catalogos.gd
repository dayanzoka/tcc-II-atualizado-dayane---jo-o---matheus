extends CasoDeTeste

## O catalogo do cliente tem que ser identico ao do banco.
##
## A lista abaixo foi transcrita a mao da migration V5__catalogo_de_eventos.sql
## e da constraint ck_tentativa_resultado (V2__pesquisa.sql). Ela e proposital-
## mente uma SEGUNDA copia: se alguem editar CatalogoEventos sem tocar no banco,
## este teste fica vermelho. Um codigo divergente nao daria erro visivel no jogo
## -- daria 4xx na ingestao, com o lote inteiro indo embora.

const EVENTOS_DA_MIGRATION_V5: PackedStringArray = [
	"SESSAO_INICIADA",
	"SESSAO_ENCERRADA",
	"SESSAO_ABANDONADA",
	"FASE_INICIADA",
	"FASE_CONCLUIDA",
	"FASE_ABANDONADA",
	"DICA_SOLICITADA",
	"CIFRA_DEMONSTRADA",
	"COMANDO_SUBMETIDO",
	"ERRO_LEXICO",
	"ERRO_SINTATICO",
	"CACHORRO_DETECTOU",
	"CACHORRO_PERDEU",
	"JOGADOR_CAPTURADO",
	"AMOSTRA_DESEMPENHO",
]

const RESULTADOS_DA_CONSTRAINT: PackedStringArray = [
	"SUCESSO",
	"ERRO_LEXICO",
	"ERRO_SINTATICO",
	"ERRO_SEMANTICO",
	"TIMEOUT",
	"ABANDONO",
]


func teste_eventos_batem_com_o_banco() -> void:
	afirmar_igual(CatalogoEventos.TODOS.size(), EVENTOS_DA_MIGRATION_V5.size(),
		"mesma quantidade de codigos da V5")
	for codigo: String in EVENTOS_DA_MIGRATION_V5:
		afirmar_verdadeiro(CatalogoEventos.existe(codigo),
			"codigo da migration presente no cliente: %s" % codigo)
	for codigo: String in CatalogoEventos.TODOS:
		afirmar_verdadeiro(EVENTOS_DA_MIGRATION_V5.has(codigo),
			"codigo do cliente existe na migration: %s" % codigo)


func teste_resultados_batem_com_a_constraint() -> void:
	afirmar_igual(CatalogoResultados.TODOS.size(), RESULTADOS_DA_CONSTRAINT.size(),
		"mesma quantidade de resultados da ck_tentativa_resultado")
	for codigo: String in RESULTADOS_DA_CONSTRAINT:
		afirmar_verdadeiro(CatalogoResultados.existe(codigo),
			"resultado da constraint presente no cliente: %s" % codigo)


func teste_codigo_inventado_nao_passa() -> void:
	afirmar_falso(CatalogoEventos.existe("CACHORRO_LATIU"), "evento inventado e rejeitado")
	afirmar_falso(CatalogoEventos.existe("sessao_iniciada"), "codigo e sensivel a caixa")
	afirmar_falso(CatalogoResultados.existe("ERRO"), "resultado abreviado e rejeitado")


func teste_limites_de_tamanho_do_schema() -> void:
	# tipo_evento.codigo e VARCHAR(40); resultado e VARCHAR(20).
	for codigo: String in CatalogoEventos.TODOS:
		afirmar_verdadeiro(codigo.length() <= 40, "codigo '%s' cabe em VARCHAR(40)" % codigo)
	for codigo: String in CatalogoResultados.TODOS:
		afirmar_verdadeiro(codigo.length() <= 20, "resultado '%s' cabe em VARCHAR(20)" % codigo)
