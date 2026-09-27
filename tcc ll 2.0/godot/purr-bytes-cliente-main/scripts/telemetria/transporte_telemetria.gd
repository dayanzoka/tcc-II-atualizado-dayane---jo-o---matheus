class_name TransporteTelemetria
extends Node

## Interface de saida da telemetria.
##
## Existe para que a troca MOCK -> HTTP seja uma linha do config.cfg e nao uma
## refatoracao (secao 1 do CLAUDE.md). A fila, o lote, a sequencia, a
## sanitizacao e a retentativa vivem em Telemetria; aqui embaixo so mora "como
## esses bytes saem daqui".
##
## E um Node, e nao um RefCounted, porque a implementacao HTTP precisa de um
## HTTPRequest como filho -- e HTTPRequest so funciona dentro da arvore.

## Rotas do contrato REST (docs/arquitetura/visao-geral.md do back-end).
## O pacote carrega a rota, e nao a URL montada, para o transporte MOCK poder
## registrar a intencao sem saber nada de HTTP.
const ROTA_ABRIR_SESSAO: String = "abrir_sessao"
const ROTA_EVENTOS: String = "eventos"
const ROTA_TENTATIVAS: String = "tentativas"
const ROTA_ENCERRAR_SESSAO: String = "encerrar_sessao"


## Toda implementacao e corrotina e cede um quadro antes de qualquer trabalho.
## Isso e o que garante a restricao 6 da secao 4: nenhuma chamada de telemetria
## pode bloquear _process ou _physics_process.
func enviar(_pacote: Dictionary) -> ResultadoEnvio:
	await _ceder_quadro()
	Registro.erro("TransporteTelemetria", "enviar() nao implementado nesta subclasse")
	return ResultadoEnvio.falha_permanente("transporte abstrato")


## Nome curto do transporte, para log e para a tela de diagnostico.
func rotulo() -> String:
	return "abstrato"


func _ceder_quadro() -> void:
	var laco := Engine.get_main_loop() as SceneTree
	if laco == null:
		return
	await laco.process_frame
