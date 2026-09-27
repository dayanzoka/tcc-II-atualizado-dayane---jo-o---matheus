extends CasoDeTeste

## ConfigJogo e o unico lugar onde a operacao da coleta mexe: e ele que carrega o
## id_sujeito do participante e decide MOCK ou HTTP no dia do teste. Configuracao
## silenciosamente errada aqui significa uma sessao inteira de dados inutil.
##
## Todos os testes apontam para arquivos em user://testes; o config.cfg real nao
## e tocado. antes()/depois() salvam e devolvem o estado do autoload, porque
## outros arquivos da suite dependem dele.

var _modo: String
var _url: String
var _chave: String
var _sujeito: String
var _lote: int
var _intervalo: float
var _nivel: String


func antes() -> void:
	_modo = ConfigJogo.modo_telemetria
	_url = ConfigJogo.url_api
	_chave = ConfigJogo.chave_api
	_sujeito = ConfigJogo.id_sujeito
	_lote = ConfigJogo.tamanho_lote
	_intervalo = ConfigJogo.intervalo_envio_s
	_nivel = ConfigJogo.nivel_log
	# Metade destes testes carrega configuracao invalida de proposito. O nivel
	# volta a valer assim que um arquivo de teste define nivel_log.
	Registro.definir_nivel_por_nome("SILENCIO")


func depois() -> void:
	ConfigJogo.modo_telemetria = _modo
	ConfigJogo.url_api = _url
	ConfigJogo.chave_api = _chave
	ConfigJogo.id_sujeito = _sujeito
	ConfigJogo.tamanho_lote = _lote
	ConfigJogo.intervalo_envio_s = _intervalo
	ConfigJogo.nivel_log = _nivel
	Registro.definir_nivel_por_nome("ERRO")


func teste_padroes_quando_o_arquivo_nao_existe() -> void:
	var caminho: String = caminho_temporario("config_ausente.cfg")
	ConfigJogo.carregar(caminho)

	afirmar_igual(ConfigJogo.modo_telemetria, ConfigJogo.MODO_MOCK,
		"nasce em MOCK: sem servidor no ar, o jogo ainda coleta")
	afirmar_igual(ConfigJogo.tamanho_lote, 50, "tamanho_lote padrao")
	afirmar_proximo(ConfigJogo.intervalo_envio_s, 5.0, 0.001, "intervalo_envio_s padrao")
	afirmar_verdadeiro(FileAccess.file_exists(caminho),
		"o arquivo e criado, para o operador ter o que editar")


func teste_ida_e_volta_do_arquivo() -> void:
	var caminho: String = caminho_temporario("config_roundtrip.cfg")
	var sujeito: String = Identificador.uuid_v4()

	var arquivo := ConfigFile.new()
	arquivo.set_value("telemetria", "modo_telemetria", "HTTP")
	arquivo.set_value("telemetria", "url_api", "http://10.0.0.7:8080")
	arquivo.set_value("telemetria", "chave_api", "chave-de-teste")
	arquivo.set_value("telemetria", "tamanho_lote", 120)
	arquivo.set_value("telemetria", "intervalo_envio_s", 2.5)
	arquivo.set_value("pesquisa", "id_sujeito", sujeito)
	arquivo.set_value("diagnostico", "nivel_log", "depuracao")
	afirmar_igual(arquivo.save(caminho), OK, "config de teste gravada")

	ConfigJogo.carregar(caminho)
	afirmar_igual(ConfigJogo.modo_telemetria, "HTTP", "modo lido do arquivo")
	afirmar_igual(ConfigJogo.url_api, "http://10.0.0.7:8080", "url lida do arquivo")
	afirmar_igual(ConfigJogo.id_sujeito, sujeito, "id_sujeito preservado sem alteracao")
	afirmar_igual(ConfigJogo.tamanho_lote, 120, "tamanho_lote lido")
	afirmar_igual(ConfigJogo.nivel_log, "DEPURACAO", "nivel_log normalizado para maiusculas")
	afirmar_igual(Registro.nome_do_nivel(), "DEPURACAO", "nivel aplicado ao Registro")


func teste_valores_fora_da_faixa_sao_corrigidos() -> void:
	var caminho: String = caminho_temporario("config_faixa.cfg")
	var arquivo := ConfigFile.new()
	arquivo.set_value("telemetria", "modo_telemetria", "carteiro")
	arquivo.set_value("telemetria", "tamanho_lote", 9000)
	arquivo.set_value("telemetria", "intervalo_envio_s", 0.01)
	arquivo.set_value("pesquisa", "id_sujeito", Identificador.uuid_v4())
	arquivo.save(caminho)

	ConfigJogo.carregar(caminho)
	afirmar_igual(ConfigJogo.modo_telemetria, ConfigJogo.MODO_MOCK,
		"modo desconhecido cai para MOCK em vez de derrubar a coleta")
	afirmar_igual(ConfigJogo.tamanho_lote, 500,
		"lote limitado ao teto do back-end (PB_MAX_LOTE)")
	afirmar_proximo(ConfigJogo.intervalo_envio_s, 0.5, 0.001,
		"intervalo minimo respeitado")


func teste_id_sujeito_invalido_gera_um_local() -> void:
	var caminho: String = caminho_temporario("config_sujeito.cfg")
	var arquivo := ConfigFile.new()
	arquivo.set_value("pesquisa", "id_sujeito", "PB-2026-0001")  # codigo, nao UUID
	arquivo.save(caminho)

	ConfigJogo.carregar(caminho)
	afirmar_verdadeiro(Identificador.e_uuid(ConfigJogo.id_sujeito),
		"id_sujeito fora do formato e substituido por um UUID valido")
	afirmar_diferente(ConfigJogo.id_sujeito, "PB-2026-0001",
		"o valor invalido nao e propagado para a sessao")


func teste_resumo_seguro_nao_vaza_a_chave() -> void:
	ConfigJogo.chave_api = "chave-super-secreta-de-ingestao"
	var resumo: Dictionary = ConfigJogo.resumo_seguro()
	var serializado: String = JSON.stringify(resumo)

	afirmar_falso(serializado.contains("chave-super-secreta-de-ingestao"),
		"a chave nao aparece no resumo (restricao 8: nunca logar, nunca exibir)")
	afirmar_verdadeiro(bool(resumo["chave_api_definida"]),
		"o resumo diz apenas se existe chave configurada")
	afirmar_falso(resumo.has("chave_api"), "nao ha campo chave_api no resumo")


func teste_versao_vem_do_project_settings() -> void:
	ConfigJogo.carregar(caminho_temporario("config_versao.cfg"))
	afirmar_igual(ConfigJogo.versao_jogo,
		String(ProjectSettings.get_setting("application/config/version", "")),
		"versao_jogo tem fonte unica: application/config/version")
	afirmar_verdadeiro(ConfigJogo.versao_jogo.length() <= 30,
		"cabe em sessao_jogo.versao_jogo VARCHAR(30)")


func teste_plataforma_cabe_no_schema() -> void:
	ConfigJogo.carregar(caminho_temporario("config_plataforma.cfg"))
	afirmar_verdadeiro(ConfigJogo.plataforma.length() > 0, "plataforma preenchida")
	afirmar_verdadeiro(ConfigJogo.plataforma.length() <= 30,
		"cabe em sessao_jogo.plataforma VARCHAR(30)")
