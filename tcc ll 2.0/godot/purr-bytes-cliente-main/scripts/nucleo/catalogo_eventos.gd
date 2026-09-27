class_name CatalogoEventos
extends RefCounted

## Codigos de evento de telemetria.
##
## Restricao 7 da secao 4 do CLAUDE.md: esta lista NAO e uma sugestao. Ela e o
## espelho exato da tabela pesquisa.tipo_evento, populada pela migration
## V5__catalogo_de_eventos.sql do back-end, e evento_telemetria.tipo_evento tem
## chave estrangeira para ela. Codigo inventado aqui = INSERT rejeitado la, ou
## seja, dado de pesquisa perdido.
##
## Nao renomear nenhum codigo apos o inicio da coleta: quebraria a serie
## historica (comentario da propria migration).

# Ciclo de vida da sessao -- Eixo 6
const SESSAO_INICIADA: String = "SESSAO_INICIADA"
const SESSAO_ENCERRADA: String = "SESSAO_ENCERRADA"
const SESSAO_ABANDONADA: String = "SESSAO_ABANDONADA"

# Progressao entre as fases -- Eixo 2
const FASE_INICIADA: String = "FASE_INICIADA"
const FASE_CONCLUIDA: String = "FASE_CONCLUIDA"
const FASE_ABANDONADA: String = "FASE_ABANDONADA"
const DICA_SOLICITADA: String = "DICA_SOLICITADA"
const CIFRA_DEMONSTRADA: String = "CIFRA_DEMONSTRADA"

# Terminal e analisador lexico-sintatico -- Eixo 3
const COMANDO_SUBMETIDO: String = "COMANDO_SUBMETIDO"
const ERRO_LEXICO: String = "ERRO_LEXICO"
const ERRO_SINTATICO: String = "ERRO_SINTATICO"

# Inteligencia artificial -- Eixo 4
const CACHORRO_DETECTOU: String = "CACHORRO_DETECTOU"
const CACHORRO_PERDEU: String = "CACHORRO_PERDEU"
const JOGADOR_CAPTURADO: String = "JOGADOR_CAPTURADO"

# Desempenho do cliente -- Eixo 7
const AMOSTRA_DESEMPENHO: String = "AMOSTRA_DESEMPENHO"

const TODOS: PackedStringArray = [
	SESSAO_INICIADA,
	SESSAO_ENCERRADA,
	SESSAO_ABANDONADA,
	FASE_INICIADA,
	FASE_CONCLUIDA,
	FASE_ABANDONADA,
	DICA_SOLICITADA,
	CIFRA_DEMONSTRADA,
	COMANDO_SUBMETIDO,
	ERRO_LEXICO,
	ERRO_SINTATICO,
	CACHORRO_DETECTOU,
	CACHORRO_PERDEU,
	JOGADOR_CAPTURADO,
	AMOSTRA_DESEMPENHO,
]


static func existe(codigo: String) -> bool:
	return TODOS.has(codigo)
