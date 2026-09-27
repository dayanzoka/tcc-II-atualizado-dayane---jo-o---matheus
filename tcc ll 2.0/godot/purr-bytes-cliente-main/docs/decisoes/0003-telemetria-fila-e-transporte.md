# ADR 0003 — Fila de telemetria, transporte plugável e carimbo de tempo

**Marco:** 0 · **Data:** 2026-08-21 · **Situação:** aceita

## Contexto

A telemetria deste projeto não é analytics de produto: é coleta de dados de
pesquisa. Evento perdido é dado perdido, e dado perdido enfraquece o resultado
estatístico. Ao mesmo tempo, o back-end ainda não tem rotas implementadas
(`docs/arquitetura/visao-geral.md`, seção 5), então o cliente precisa nascer
funcional sem servidor nenhum no ar.

## Decisões

### 1. Transporte é uma fronteira, não um `if`

`Telemetria` (autoload) cuida de sequência, sanitização, lote, persistência e
backoff. `TransporteTelemetria` (`scripts/telemetria/`) cuida apenas de *como os
bytes saem*: `TransporteMock` escreve JSONL em disco, `TransporteHttp` fala com a
API no Marco 3.

Consequência: trocar MOCK por HTTP é uma linha do `config.cfg`, não uma
refatoração. O Marco 3 preenche `TransporteHttp.enviar()` e vira
`disponivel()` para `true`; `telemetria.gd` não é tocado.

Enquanto `disponivel()` for `false`, pedir `modo_telemetria = "HTTP"` cai para
MOCK **com erro no log**, em vez de deixar a fila crescer sem destino.

### 2. Um único escritor de sequência

O `CLAUDE.md` lista "sequência" entre as responsabilidades de `Sessao`. Ela ficou
em `Telemetria`. Motivo: a restrição 5 exige sequência monotônica sem lacuna, e a
garantia mais barata disso é ter um só ponto do código capaz de furá-la. Todo
evento passa por `registrar_evento()`, então é lá que o número é atribuído — e é
só isso que precisa ser auditado.

Corolário: evento com código fora do catálogo é descartado **antes** de consumir
número, para o descarte não abrir buraco na série.

### 3. Escrita adiantada da fila

A fila é persistida em `user://fila_telemetria.json` antes da primeira tentativa
de envio, e não depois. Um processo morto no meio de um envio perde, no máximo,
os eventos gerados desde o último tique — nunca a fila inteira. A gravação é em
arquivo temporário seguido de `rename`, porque JSON truncado é fila inteira
perdida.

Sessão que aparece aberta no disco no boot seguinte vira `SESSAO_ABANDONADA`
continuando a sequência salva. Isso distingue, na análise, quem desistiu de quem
teve o processo encerrado por acidente.

### 4. Falha permanente ≠ falha transitória

`4xx` descarta o lote e grita no log; `5xx` e falha de rede preservam a fila e
agendam retentativa com backoff exponencial e jitter. Confundir os dois é como se
perde dado de pesquisa em silêncio — ou como se entra em laço infinito de
reenvio de um lote que nunca vai ser aceito.

O jitter existe porque uma sala de aula inteira perde a rede no mesmo instante e
voltaria a bater na API no mesmo milissegundo.

### 5. Teto de fila com descarte do mais antigo

`MAX_ITENS_EM_FILA = 20000`. Acima disso o cliente descarta o registro mais
antigo e conta o descarte em `estatisticas()`. Preferir perder o início a
derrubar o jogo no meio da coleta; em análise de aprendizado o fim da partida diz
mais que o começo. O descarte nunca é silencioso.

### 6. Carimbo de tempo montado à mão

`Time.get_datetime_string_from_system(true, true)`, que o briefing sugeria,
devolve `2026-08-21 23:04:16`: separador de espaço e **sem designador de fuso**.
Um `TIMESTAMPTZ` recebendo isso assume o fuso da sessão do banco e desloca todo
`ocorrido_em` em algumas horas — erro silencioso que só apareceria na análise.

`Relogio.agora_utc_iso()` devolve `2026-08-21T23:04:16.397Z`. Milissegundos
porque `COMANDO_SUBMETIDO` e `ERRO_LEXICO` caem no mesmo segundo com frequência.
Duração usa `Time.get_ticks_msec()` (monotônico): se o sistema ajustar a hora por
NTP no meio de uma tentativa, o `tempo_resposta_ms` não pode sair negativo e
violar `ck_tentativa_tempo`.

### 7. Truncamento na entrada da fila

Texto livre é sanitizado e truncado em 240 caracteres **ao entrar na fila**, não
ao sair. Assim o arquivo do modo MOCK também já está conforme, e serve como
evidência de conformidade — não só o que chega no servidor.

## Consequências

- O jogo continua jogável com a API fora, por construção e não por sorte.
- O arquivo do modo MOCK é dado de pesquisa utilizável, não log de depuração.
- O Marco 3 fica reduzido a implementar `TransporteHttp.enviar()` e testá-lo
  contra o servidor de eco.
