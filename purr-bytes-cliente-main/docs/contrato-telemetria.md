# Contrato de telemetria — o que o cliente Godot envia

Este documento é a referência para quem for implementar as rotas de ingestão no
back-end (`Morc3go/prototipo`, `Protótipo/backend`). Todos os exemplos abaixo
foram **gerados pelo cliente**, não escritos à mão:

```powershell
godot --headless --path . --script res://tools/sessao_de_demonstracao.gd
```

O comando monta `cenas/fases/fase_01.tscn` de verdade e aciona o pipeline pelo
mesmo caminho que o jogador usa (o sinal `Terminal.comando_submetido`) —
imprime exatamente os corpos que iriam para a rede. Reexecute-o sempre que
mudar a serialização — se a saída divergir deste arquivo, este arquivo está
desatualizado. (A versão anterior deste roteiro escrevia os payloads à mão;
foi assim que o exemplo de TC-04 abaixo ficou incorreto por dois marcos —
classificado como `ERRO_LEXICO` quando o ADR 0006 já tinha decidido
`ERRO_SINTATICO`. Gerar de verdade, executando o código, é o que evita esse
tipo de deriva.)

Estado em 2026-08-23 (Marco 3): as rotas **ainda não existem** no back-end de
produção (`Morc3go/prototipo`). O transporte HTTP (`scripts/telemetria/
transporte_http.gd`) já está implementado e testado contra
`tools/servidor_eco.py`, um servidor de eco local (`python tools/servidor_eco.py
<porta> <arquivo_de_log>`) que aceita qualquer `POST` nas rotas abaixo e
responde `202`. `tests/teste_transporte_http.gd` e
`tests/teste_resiliencia_http.gd` validam o cliente contra ele.

---

## 0. MUDANÇA DE CONTRATO — `id_fase` (2026-09-14)

**Para o time do banco.** O cliente deixou de identificar a fase pelo número.

Motivo: o esquema nasceu com quatro fases fixas (`CHECK (fase BETWEEN 1 AND 4)`), e o
cliente honrava isso **descartando** qualquer evento ou tentativa fora dessa faixa. Com
fases criadas livremente, esse descarte significaria perder a telemetria da maioria das
fases — o oposto do que a instrumentação existe para fazer.

O que muda no corpo enviado:

| campo | antes | agora |
|---|---|---|
| `id_fase` | — | **novo, sempre presente.** UUID v4 estável, gerado uma vez por fase e gravado no recurso dela. É a chave de ligação fase ↔ eventos. |
| `titulo_fase` | — | **novo**, ≤ 60 caracteres. Rótulo legível, só para diagnóstico. |
| `fase` | número 1..4, obrigatório em `tentativa_comando` | **legado e opcional.** Continua indo quando está em 1..4; vai `null` fora disso. |

O cliente **nunca mais descarta** um registro por causa do número da fase.

Enquanto o `CHECK` existir no banco de produção, o cliente segue anulando `fase` fora de
1..4 — não por amarra própria, mas porque um valor fora da faixa faria a API recusar o
**lote inteiro** (4xx = erro permanente = lote descartado), levando junto centenas de
registros válidos. A identidade real já está em `id_fase`.

**O que pedimos ao banco:** uma coluna `id_fase UUID` em `evento_telemetria` e
`tentativa_comando` (mais `titulo_fase VARCHAR(60)` se for útil), e a remoção do
`CHECK (fase BETWEEN 1 AND 4)`. Feito isso, o cliente para de anular o campo numérico —
é uma linha em `autoload/telemetria.gd`, já marcada em comentário.

`id_fase` é técnico e anônimo: não deriva de nada pessoal e não identifica participante.
O pseudônimo do sujeito continua sendo só `id_sujeito`.

---

## 1. Rotas

| Método | Rota | Quando |
|---|---|---|
| `POST` | `/v1/sessoes` | Abertura de sessão. Idempotente pelo `id_sessao` do corpo. |
| `POST` | `/v1/sessoes/{id}/eventos` | Lote de eventos. Idempotente pelo `id_evento`. |
| `POST` | `/v1/sessoes/{id}/tentativas` | Lote de tentativas. Idempotente pelo `id_tentativa`. |
| `POST` | `/v1/sessoes/{id}/encerrar` | Encerramento da sessão. |

Header: `Authorization: Bearer <chave_api>`, escopo `INGESTAO`.

**Ordem garantida pelo cliente:** abertura → eventos → tentativas →
encerramento. A fila só passa para a próxima categoria quando a anterior esvazia,
porque `evento_telemetria.id_sessao` tem chave estrangeira para
`sessao_jogo.id_sessao`: evento que chega antes da sessão não tem onde ser
gravado.

### Como o cliente interpreta a resposta

| Faixa | Interpretação | O que o cliente faz |
|---|---|---|
| `2xx` (a API responde `202`) | Aceito para processamento | Remove o lote da fila |
| `4xx` | Erro permanente — o lote está malformado | **Descarta** o lote e registra erro alto |
| `5xx`, timeout, sem rede | Erro transitório | **Preserva** a fila e tenta de novo com backoff exponencial + jitter (teto de 60s) |

Reenvio após queda de conexão é esperado e normal: o cliente não sabe se o lote
chegou, então manda de novo. Os IDs vêm do cliente exatamente para isso — o
servidor deve ignorar duplicatas em silêncio, não devolver erro.

---

## 2. `POST /v1/sessoes`

```json
{
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "id_sujeito": "bea35bec-8177-44c0-853d-2c7a5a04ecbf",
  "versao_jogo": "0.1.0",
  "plataforma": "Windows",
  "iniciada_em": "2026-08-21T23:04:16.396Z"
}
```

Mapeia campo a campo as colunas `NOT NULL` de `pesquisa.sessao_jogo`. O servidor
preenche `recebida_em` com o próprio relógio e `status` com `ABERTA`.

`plataforma` vem de `OS.get_name()` — família de sistema operacional
(`Windows`, `Linux`, `macOS`, `Android`, `iOS`, `Web`), nunca identificador de
máquina.

---

## 3. `POST /v1/sessoes/{id}/eventos`

Corpo: `{"eventos": [ ... ]}`, cada elemento no formato abaixo.

```json
{
  "id_evento": "b27be993-d972-4781-a39a-7c2189cfcb58",
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "sequencia": 1,
  "tipo_evento": "FASE_INICIADA",
  "fase": 1,
  "ocorrido_em": "2026-08-21T23:04:16.397Z",
  "payload": {"algoritmo": "CESAR", "desafios": 1, "vidas_iniciais": 3}
}
```

Evento fora de fase (`SESSAO_INICIADA`, `SESSAO_ENCERRADA`) manda `fase` como
`null` — a coluna é nulável mas tem `CHECK (fase BETWEEN 1 AND 4)`:

```json
{
  "id_evento": "331f4524-0edd-4aba-b1f9-5c888e986435",
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "sequencia": 0,
  "tipo_evento": "SESSAO_INICIADA",
  "fase": null,
  "ocorrido_em": "2026-08-21T23:04:16.396Z",
  "payload": {"modo_telemetria": "MOCK"}
}
```

### `sequencia`

Contador monotônico por sessão, começando em **0**, sem lacunas, atribuído por um
escritor único no cliente. Lacuna na série significa perda de pacote — é para
isso que o campo existe. O cliente garante:

- código de evento fora do catálogo é descartado **antes** de consumir número;
- a sequência é persistida junto com a fila, então sobrevive a queda do processo.

`UNIQUE (id_sessao, sequencia)` no banco fecha o contrato do outro lado.

### `payload`

JSONB livre por tipo de evento, com três garantias do cliente:

1. nenhum dado pessoal (restrição 1 da seção 4 do `CLAUDE.md`);
2. toda string é sanitizada (sem caractere de controle, espaços colapsados) e
   truncada em **240** caracteres, inclusive dentro de objetos e listas aninhados;
3. `Vector2` vira `{"x": …, "y": …}`, nunca a string `"(3, 4)"`.

Payloads por tipo de evento usados até aqui:

| `tipo_evento` | `payload` |
|---|---|
| `SESSAO_INICIADA` | `{"modo_telemetria": "MOCK"\|"HTTP"}` |
| `SESSAO_ENCERRADA` / `SESSAO_ABANDONADA` | `{"status": "ENCERRADA"\|"ABANDONADA"}` (+ `motivo` no abandono) |
| `FASE_INICIADA` | `{"algoritmo", "desafios", "vidas_iniciais"}` |
| `FASE_CONCLUIDA` | `{"capturas", "pontuacao", "vidas_restantes"}` |
| `FASE_ABANDONADA` | `{"capturas", "pontuacao"}` |
| `COMANDO_SUBMETIDO` | `{"tamanho", "tempo_resposta_ms"}` |
| `ERRO_LEXICO` / `ERRO_SINTATICO` | `{}` — o detalhe do erro vai na `tentativa_comando` correspondente (`tokens` + `codigo_erro`), não duplicado aqui |
| `DICA_SOLICITADA` | `{"desafio"}` |
| `CIFRA_DEMONSTRADA` | `{"algoritmo"}` |
| `JOGADOR_CAPTURADO` | `{"protecao_ativa", "captura_numero"}` |
| `CACHORRO_DETECTOU` | `{"posicao": {"x", "y"}}` |
| `CACHORRO_PERDEU` | `{}` |
| `AMOSTRA_DESEMPENHO` | `{"fps", "memoria_estatica_bytes", "objetos_desenhados", "replanejamento_medio_ms"}` (Eixo 7 — média desde a amostra anterior, a cada 30s) |

**A lista de códigos é fechada** e espelha `V5__catalogo_de_eventos.sql`;
`tests/teste_catalogos.gd` compara as duas e falha se divergirem.

---

## 4. `POST /v1/sessoes/{id}/tentativas`

Corpo: `{"tentativas": [ ... ]}`.

`codigo_erro` é **vocabulário fixo e curto** (`caractere_invalido`,
`token_inesperado`, `verbo_nao_permitido`, `chave_incorreta`, ... — lista
completa e o porquê de cada um em
[ADR 0006](decisoes/0006-analisador-lexico-sintatico.md)), não texto livre com
a posição embutida — a posição já está em `tokens`.

Caso TC-04 da monografia (`cyfrar pacote chave=3`) — o AFD tokeniza `cyfrar`
como `IDENTIFICADOR` (não é uma palavra reservada da gramática), e é o parser
que rejeita por faltar `VERBO` na primeira posição:

```json
{
  "id_tentativa": "8521f615-1b22-4850-b393-c640d9218fd3",
  "id_sessao": "ebc7847c-3345-4a19-bd83-852b01fe6a46",
  "fase": 1,
  "desafio": "cesar-01",
  "entrada_normalizada": "cyfrar pacote chave=3",
  "tokens": [
    {"tipo": "IDENTIFICADOR", "lexema": "cyfrar", "posicao": 0},
    {"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7},
    {"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14},
    {"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19},
    {"tipo": "NUMERO", "lexema": "3", "posicao": 20},
    {"tipo": "EOF", "lexema": "", "posicao": 21}
  ],
  "resultado": "ERRO_SINTATICO",
  "codigo_erro": "token_inesperado",
  "tempo_resposta_ms": 4310,
  "numero_tentativa": 1,
  "ocorrido_em": "2026-08-23T05:04:46.058Z"
}
```

Erro léxico de verdade (`cifrar pacote!` — `!` não pertence ao alfabeto da
gramática): o AFD nem chega a formar todos os tokens, então `tokens` sai
vazio — não há árvore nenhuma para descrever, o erro é anterior a isso.

```json
{
  "id_tentativa": "3e6c70bc-9c49-4d19-977c-f9f6984cd65a",
  "id_sessao": "ebc7847c-3345-4a19-bd83-852b01fe6a46",
  "fase": 1,
  "desafio": "cesar-01",
  "entrada_normalizada": "cifrar pacote!",
  "tokens": [],
  "resultado": "ERRO_LEXICO",
  "codigo_erro": "caractere_invalido",
  "tempo_resposta_ms": 1200,
  "numero_tentativa": 1,
  "ocorrido_em": "2026-08-23T05:04:46.058Z"
}
```

Acerto — `numero_tentativa` continua **1**: as duas tentativas acima nunca
passaram da etapa léxico-sintática, então nunca chegaram ao resolvedor
semântico e não contam como "tentativa real" do desafio (ver
[ADR 0007](decisoes/0007-marco1-cachorro-e-desafios.md), decisão 4):

```json
{
  "id_tentativa": "3c54b4da-1dd5-4794-8e2e-84a270a42e9b",
  "id_sessao": "ebc7847c-3345-4a19-bd83-852b01fe6a46",
  "fase": 1,
  "desafio": "cesar-01",
  "entrada_normalizada": "cifrar pacote chave=3",
  "tokens": [
    {"tipo": "VERBO", "lexema": "cifrar", "posicao": 0},
    {"tipo": "IDENTIFICADOR", "lexema": "pacote", "posicao": 7},
    {"tipo": "IDENTIFICADOR", "lexema": "chave", "posicao": 14},
    {"tipo": "ATRIBUICAO", "lexema": "=", "posicao": 19},
    {"tipo": "NUMERO", "lexema": "3", "posicao": 20},
    {"tipo": "EOF", "lexema": "", "posicao": 21}
  ],
  "resultado": "SUCESSO",
  "codigo_erro": null,
  "tempo_resposta_ms": 2180,
  "numero_tentativa": 1,
  "ocorrido_em": "2026-08-23T05:04:46.066Z"
}
```

Garantias do cliente, todas cobertas por teste:

| Campo | Garantia |
|---|---|
| `desafio` | ≤ 60 caracteres (`VARCHAR(60)`) |
| `entrada_normalizada` | sanitizada e ≤ 240 (`VARCHAR(240)` e `limite-texto-livre`) |
| `resultado` | um de `SUCESSO`, `ERRO_LEXICO`, `ERRO_SINTATICO`, `ERRO_SEMANTICO`, `TIMEOUT`, `ABANDONO` |
| `codigo_erro` | `null` em caso de sucesso; vocabulário fixo, ≤ 40 caracteres |
| `tempo_resposta_ms` | ≥ 0, medido com relógio monotônico do foco no terminal até o Enter |
| `numero_tentativa` | ≥ 1, conta só tentativas que passaram léxico + sintático para o verbo esperado pelo desafio |

Nota: `tentativa_comando` **não tem** coluna `sequencia`. Ordem e detecção de
perda vivem em `evento_telemetria`.

### Tentativas vindas da caixa de puzzle do pacote

Desde o ADR 0010, a escolha feita na caixa de puzzle de um pacote também entra
por esta rota — **não** há tipo de evento novo (o catálogo é fechado pelo banco).
Elas se distinguem pelo prefixo `pacote-` em `desafio`, e por `tokens` vazio
(a resposta é um clique, não uma linha de comando):

```json
{
  "id_tentativa": "6d1cb1a0-2b17-4b1a-9f0d-2b2f2b5aa771",
  "id_sessao": "ebc7847c-3345-4a19-bd83-852b01fe6a46",
  "fase": 1,
  "desafio": "pacote-cesar-ne",
  "entrada_normalizada": "VIGENERE",
  "tokens": [],
  "resultado": "ERRO_SEMANTICO",
  "codigo_erro": "opcao_incorreta",
  "tempo_resposta_ms": 5120,
  "numero_tentativa": 1,
  "ocorrido_em": "2026-08-25T19:41:02.311Z"
}
```

`entrada_normalizada` é o código do algoritmo escolhido (`CESAR`, `VIGENERE`,
`SHA256`, `AES`); acerto sai como `SUCESSO` com `codigo_erro` nulo. A distinção
importa para a análise: `pacote-*` mede **escolher a ferramenta certa**, as
demais linhas medem **operar a cifra certa** — são competências diferentes e o
pré/pós-teste mede as duas.

---

## 5. `POST /v1/sessoes/{id}/encerrar`

```json
{
  "id_sessao": "d74c9f6e-818f-4fd5-bf5a-59427d614f1b",
  "status": "ENCERRADA",
  "encerrada_em": "2026-08-21T23:04:16.397Z"
}
```

`status` é `ENCERRADA` (saiu pelo menu) ou `ABANDONADA`. O cliente marca
`ABANDONADA` sozinho quando encontra, no boot seguinte, uma sessão que ficou
aberta no disco — travamento, queda de energia, fim de aula. Nesse caso ele
também envia um evento `SESSAO_ABANDONADA` continuando a sequência de onde
parou, sem lacuna.

---

## 6. Carimbos de tempo

Formato: **ISO-8601 UTC com milissegundos e `Z` explícito** —
`2026-08-21T23:04:16.397Z`.

Cuidado documentado em `scripts/nucleo/relogio.gd`: a chamada
`Time.get_datetime_string_from_system(true, true)` do Godot produz
`2026-08-21 23:04:16` — separador de espaço e **sem designador de fuso**. Um
`TIMESTAMPTZ` recebendo string sem fuso assume o fuso da sessão do banco, o que
deslocaria silenciosamente todo `ocorrido_em`. O cliente monta o carimbo à mão
por isso.

O servidor grava o próprio relógio em `recebido_em`. A diferença entre os dois é
a defasagem (`max-defasagem-relogio-minutos`); lote fora da tolerância deve ser
aceito e marcado, nunca recusado — o dado ainda vale, só o horário é suspeito.

---

## 7. Lote

- Tamanho de descarga: `tamanho_lote` do `config.cfg`, padrão **50**.
- Teto absoluto: **500** (`purrbytes.ingestao.max-eventos-por-lote`). O cliente
  limita o próprio lote a esse valor mesmo que o `config.cfg` peça mais.
- Cadência: a cada `intervalo_envio_s` (padrão 5s) ou assim que a fila atinge
  `tamanho_lote`.
- A fila é persistida em `user://fila_telemetria.json` **antes** de cada
  tentativa de envio (escrita adiantada) e no fechamento da janela.

---

## 8. Formato do modo MOCK

Em `modo_telemetria = "MOCK"` o cliente grava `user://telemetria_mock.jsonl`, uma
linha JSON por registro:

```json
{"rota": "eventos", "tipo_registro": "evento", "escrito_em": "…", "dados": { … }}
```

`dados` é **exatamente** o objeto que iria no corpo da requisição — é isso que
torna o arquivo do modo MOCK utilizável como dado de pesquisa caso a API esteja
fora no dia da coleta. `tipo_registro` é `sessao`, `evento` ou `tentativa`.
