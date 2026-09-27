extends Node

## Autoload ConfigJogo -- configuracao externalizada do cliente.
##
## Le user://config.cfg com ConfigFile (classe nativa: ja resolve parsing,
## secoes, tipos e escrita atomica). O arquivo fica em user:// e nao em res://
## porque precisa ser editavel na maquina da escola sem reexportar o jogo: e ele
## que carrega o id_sujeito daquele participante e a URL da API do dia do teste.
##
## Restricao 8 da secao 4 do CLAUDE.md: a chave_api tem escopo INGESTAO (so
## escreve) e vai vazar, porque acompanha um binario distribuido. Tratar como
## publica -- mas nunca logar nem exibir, para nao facilitar. Por isso
## resumo_seguro() existe e _to_string() nao imprime a chave.

signal configuracao_carregada

const CAMINHO_PADRAO: String = "user://config.cfg"

const MODO_MOCK: String = "MOCK"
const MODO_HTTP: String = "HTTP"

const _SECAO_TELEMETRIA: String = "telemetria"
const _SECAO_PESQUISA: String = "pesquisa"
const _SECAO_DIAGNOSTICO: String = "diagnostico"
const _SECAO_JOGO: String = "jogo"

## MOCK grava em disco local, HTTP fala com a API. A troca entre os dois e uma
## linha do config.cfg -- nunca uma alteracao de codigo (secao 1 do CLAUDE.md).
var modo_telemetria: String = MODO_MOCK
var url_api: String = "http://localhost:8080"
## Nao logar, nao exibir, nao serializar em lugar nenhum que nao seja o header
## Authorization.
var chave_api: String = ""
## UUID do sujeito da pesquisa. Pseudonimo: nao ha nome nem e-mail no cliente.
var id_sujeito: String = ""
var versao_jogo: String = ""
var tamanho_lote: int = 50
var intervalo_envio_s: float = 5.0
var nivel_log: String = "INFO"

## Modo de treino de agente (aprendizado por reforco): desliga as mecanicas que
## existem para o JOGADOR HUMANO e nao para um agente -- a caixa de puzzle do
## pacote (que exige leitura e clique) e a exigencia de que a cifra ativa case
## com a cor do cachorro. Com modo_treino ligado o pacote e coletado ao encostar
## e qualquer cifra ativa protege, que e o contrato antigo do ambiente.
##
## Fica aqui, e nao numa constante de fase_base.gd, porque trocar de modo tem
## que ser uma linha do config.cfg -- pelo mesmo motivo de modo_telemetria:
## quem treina o agente nao deveria precisar reexportar o jogo. E false por
## padrao: o jogo distribuido ao participante da pesquisa e sempre o humano.
var modo_treino: bool = false

## Derivado, nao configuravel: alimenta sessao_jogo.plataforma (VARCHAR(30)).
## OS.get_name() devolve "Windows", "Linux", "macOS", "Android", "iOS" ou "Web"
## -- nome de familia de sistema, nao identificador de maquina.
var plataforma: String = ""

var _caminho_em_uso: String = CAMINHO_PADRAO


func _ready() -> void:
	carregar(CAMINHO_PADRAO)


## Recarrega a configuracao de um caminho arbitrario. O parametro existe para os
## testes apontarem para um arquivo temporario em vez do config.cfg real.
func carregar(caminho: String) -> void:
	_caminho_em_uso = caminho
	plataforma = OS.get_name().substr(0, 30)
	versao_jogo = String(ProjectSettings.get_setting("application/config/version", "0.0.0"))

	var arquivo := ConfigFile.new()
	var erro: Error = arquivo.load(caminho)
	if erro != OK:
		Registro.aviso("ConfigJogo",
			"config nao encontrada em %s (erro %d); criando com os padroes" % [caminho, erro])
		_garantir_id_sujeito()
		salvar(caminho)
		_aplicar_nivel_de_log()
		configuracao_carregada.emit()
		return

	modo_telemetria = String(arquivo.get_value(
		_SECAO_TELEMETRIA, "modo_telemetria", modo_telemetria)).to_upper()
	url_api = String(arquivo.get_value(_SECAO_TELEMETRIA, "url_api", url_api))
	chave_api = String(arquivo.get_value(_SECAO_TELEMETRIA, "chave_api", chave_api))
	tamanho_lote = int(arquivo.get_value(_SECAO_TELEMETRIA, "tamanho_lote", tamanho_lote))
	intervalo_envio_s = float(arquivo.get_value(
		_SECAO_TELEMETRIA, "intervalo_envio_s", intervalo_envio_s))
	id_sujeito = String(arquivo.get_value(_SECAO_PESQUISA, "id_sujeito", id_sujeito))
	nivel_log = String(arquivo.get_value(
		_SECAO_DIAGNOSTICO, "nivel_log", nivel_log)).to_upper()
	modo_treino = bool(arquivo.get_value(_SECAO_JOGO, "modo_treino", modo_treino))

	_validar()
	_aplicar_nivel_de_log()
	configuracao_carregada.emit()


func salvar(caminho: String = "") -> Error:
	var destino: String = caminho if caminho != "" else _caminho_em_uso
	var arquivo := ConfigFile.new()
	arquivo.set_value(_SECAO_TELEMETRIA, "modo_telemetria", modo_telemetria)
	arquivo.set_value(_SECAO_TELEMETRIA, "url_api", url_api)
	arquivo.set_value(_SECAO_TELEMETRIA, "chave_api", chave_api)
	arquivo.set_value(_SECAO_TELEMETRIA, "tamanho_lote", tamanho_lote)
	arquivo.set_value(_SECAO_TELEMETRIA, "intervalo_envio_s", intervalo_envio_s)
	arquivo.set_value(_SECAO_PESQUISA, "id_sujeito", id_sujeito)
	arquivo.set_value(_SECAO_DIAGNOSTICO, "nivel_log", nivel_log)
	arquivo.set_value(_SECAO_JOGO, "modo_treino", modo_treino)

	var erro: Error = arquivo.save(destino)
	if erro != OK:
		Registro.erro("ConfigJogo", "falha ao salvar %s (erro %d)" % [destino, erro])
	return erro


func em_modo_mock() -> bool:
	return modo_telemetria == MODO_MOCK


## Tudo o que pode ser mostrado na tela de diagnostico ou escrito em log. A
## chave_api nao aparece nem truncada.
func resumo_seguro() -> Dictionary:
	return {
		"modo_telemetria": modo_telemetria,
		"url_api": url_api,
		"chave_api_definida": not chave_api.is_empty(),
		"id_sujeito": id_sujeito,
		"versao_jogo": versao_jogo,
		"plataforma": plataforma,
		"tamanho_lote": tamanho_lote,
		"intervalo_envio_s": intervalo_envio_s,
		"nivel_log": nivel_log,
		"modo_treino": modo_treino,
	}


func _validar() -> void:
	if modo_telemetria != MODO_MOCK and modo_telemetria != MODO_HTTP:
		Registro.erro("ConfigJogo",
			"modo_telemetria invalido (%s); usando %s" % [modo_telemetria, MODO_MOCK])
		modo_telemetria = MODO_MOCK

	# Teto do lote no back-end: PB_MAX_LOTE, padrao 500. Enviar acima disso e
	# 4xx garantido, ou seja, lote descartado.
	if tamanho_lote < 1 or tamanho_lote > 500:
		Registro.aviso("ConfigJogo",
			"tamanho_lote fora da faixa 1..500 (%d); ajustando" % tamanho_lote)
		tamanho_lote = clampi(tamanho_lote, 1, 500)

	if intervalo_envio_s < 0.5:
		Registro.aviso("ConfigJogo", "intervalo_envio_s muito baixo; ajustando para 0.5")
		intervalo_envio_s = 0.5

	_garantir_id_sujeito()


func _garantir_id_sujeito() -> void:
	if Identificador.e_uuid(id_sujeito):
		return
	# Sem id_sujeito valido o dado nao pareia com o pre-teste e o pos-teste
	# (vw_ganho_aprendizado). Gerar um localmente mantem a sessao gravavel e
	# rastreavel, mas ela fica orfa na analise -- por isso o aviso e ruidoso.
	var anterior: String = id_sujeito
	id_sujeito = Identificador.uuid_v4()
	Registro.aviso("ConfigJogo", (
		"id_sujeito ausente ou fora do formato UUID (%s). Gerado um local: %s. "
		+ "Esta sessao NAO estara pareada com o pre/pos-teste do participante."
	) % ["<vazio>" if anterior.is_empty() else anterior, id_sujeito])


func _aplicar_nivel_de_log() -> void:
	Registro.definir_nivel_por_nome(nivel_log)
	Registro.info("ConfigJogo", "configuracao carregada: %s" % JSON.stringify(resumo_seguro()))
