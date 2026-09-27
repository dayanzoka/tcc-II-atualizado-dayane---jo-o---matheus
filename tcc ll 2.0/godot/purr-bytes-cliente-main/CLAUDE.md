# Purr Bytes — Especificação técnica do cliente Godot (Fases 1 a 3)

> **Como usar este documento.** É o contexto permanente do projeto: arquitetura, restrições
> inegociáveis e critérios de aceite, organizados por marco de entrega. Antes de implementar
> qualquer marco, leia este documento inteiro e os ADRs em `docs/decisoes/`. Um marco só
> começa quando o anterior tem seus critérios de aceite verdes.

---

## 1. Contexto

**Purr Bytes** é um jogo educacional 2D em pixel art para ensino de letramento digital e
criptografia, desenvolvido como TCC de Ciência da Computação (Universidade Positivo, 2026,
orientação Prof. Me. Leandro Escobar). O jogo não é o produto final: ele é o **instrumento
experimental** de uma pesquisa que compara o conhecimento dos participantes antes e depois
de jogar. Isso muda as prioridades de engenharia:

- Telemetria não é analytics de produto — é **coleta de dados de pesquisa**. Evento perdido
  é dado perdido, e dado perdido é resultado estatístico enfraquecido.
- Todo comportamento observável precisa ser **explicável e demonstrável para uma banca**.
  Código que funciona mas não é auditável na tela vale menos aqui do que em produção.
- Nenhum dado pessoal pode sair do cliente. Nunca. Ver seção 4.

O jogo tem quatro fases, uma por algoritmo criptográfico: **César (1), Vigenère (2),
SHA-256 (3), AES simplificado (4)**. Este briefing cobre as **fases 1 a 3** mais toda a
fundação arquitetural. A fase 4 fica para depois e deve custar apenas configuração, não
código estrutural novo — se custar mais que isso, a arquitetura falhou.

### O que já existe (e você não deve reescrever)

| Artefato | Estado | Onde |
|---|---|---|
| Back-end de telemetria (Java 21 + Spring Boot 3.4 + PostgreSQL + Flyway) | Schema completo aplicado: 13 tabelas, 4 visões. Rotas REST ainda **não implementadas** | Repositório `Morc3go/prototipo`, pasta `Protótipo/backend` |
| Catálogo de eventos de telemetria | Fechado e versionado no banco (`V5__catalogo_de_eventos.sql`) | idem |
| Classificação LGPD campo a campo | Pronta | `Protótipo/docs/lgpd/classificacao-de-dados.md` |
| Decisões de arquitetura + contrato REST alvo | Pronto | `Protótipo/docs/arquitetura/visao-geral.md` |
| Protótipo Godot anterior | Existe, mas é **descartável** | Fora deste repositório |

**Consequência prática:** o servidor ainda não responde. O cliente precisa nascer funcional
com a telemetria em **modo MOCK**, e a troca para o modo HTTP tem que ser uma variável de
configuração — não uma refatoração.

---

## 2. Stack e versão

- **Godot 4.4 ou superior**, GDScript com **tipagem estática obrigatória**.
- Sem addons de terceiros no núcleo do jogo. Exceção permitida: framework de testes
  (**GUT** ou **gdUnit4**), instalado em `addons/` e usado apenas em `tests/`.
- Renderizador: **Mobile** (suficiente e mais leve — requisito não funcional é rodar em
  hardware escolar padrão).
- Pixel art: `Project Settings → Rendering → Textures → Canvas Textures → Default Texture
  Filter = Nearest`; `Display → Window → Stretch → Mode = canvas_items`, `Aspect = keep`.
  Resolução base **640×360**.

### Regra das ferramentas nativas

**Prefira sempre a ferramenta nativa da engine à implementação artesanal.** Onde houver
classe do Godot que resolve, use a classe do Godot e comente no código por que ela foi
escolhida. A lista mínima do que deve ser usado:

| Necessidade | Use |
|---|---|
| Pathfinding em grade | `AStarGrid2D` |
| Mapa e colisão do labirinto | `TileMapLayer` + `TileSet` com **custom data layers** |
| Personagens | `CharacterBody2D` + `move_and_slide()`; gatilhos com `Area2D` |
| Configuração de fase | `Resource` customizado salvo em `.tres` |
| Reuso entre fases | **Herança de cena** (`Scene → New Inherited Scene`) |
| Serviços globais | **Autoload** (singletons) |
| HTTP assíncrono | Nó `HTTPRequest` |
| SHA-256 | `HashingContext` (`HASH_SHA256`) — não implemente hash à mão |
| Bytes aleatórios / UUID | `Crypto.generate_random_bytes()` |
| JSON | `JSON.stringify` / `JSON.parse_string` |
| Timestamp UTC ISO-8601 | `Time.get_datetime_string_from_system(true, true)` |
| Métrica de FPS/memória | `Performance.get_monitor()` |
| Ajuste fino pelo Inspector | `@export`, `@export_range`, `@export_group` |
| Depuração visual | `_draw()` + `queue_redraw()`, `Debug → Visible Collision Shapes` |

**Uma exceção deliberada, e só uma.** O A\* é objeto de avaliação da banca (apontamento 14:
"justificar o uso do A\* com explicação do algoritmo"). Por isso o projeto terá **duas**
implementações:

1. `AStarGrid2D` — é o que roda no jogo.
2. `scripts/ia/astar_referencia.gd` — implementação didática, comentada, com fila de
   prioridade explícita, `g`, `h`, `f`, conjunto aberto e fechado. **Não é usada em runtime.**
   Existe para (a) gerar o pseudocódigo da monografia, (b) ser lida na defesa e (c) servir de
   oráculo nos testes: um teste compara o custo do caminho das duas implementações em mapas
   gerados e falha se divergirem.

Isso resolve o dilema entre "usar a engine" e "provar que sabemos o algoritmo" sem
comprometer nenhum dos dois. Documente essa decisão em `docs/decisoes/0001-astar.md`.

---

## 3. Arquitetura alvo

O requisito não funcional mais importante da monografia é: *"arquitetura modular de alta
manutenibilidade, permitindo a adição de novas fases com baixo esforço de codificação,
através do uso de matrizes de dados"*. A tradução disso em Godot é **uma cena pai com toda a
lógica e cenas filhas que só carregam dados**.

```
res://
├── project.godot
├── CLAUDE.md                      este documento
├── autoload/
│   ├── telemetria.gd              fila, lote, retentativa, modo MOCK
│   ├── sessao.gd                  id_sessao, sequência, vidas, pontuação
│   └── config_jogo.gd             leitura de config.cfg (modo, URL, chave)
├── cenas/
│   ├── base/
│   │   ├── fase_base.tscn/.gd     CENA PAI — não é jogável sozinha
│   │   ├── jogador.tscn/.gd
│   │   ├── cachorro.tscn/.gd
│   │   └── terminal.tscn/.gd
│   ├── fases/
│   │   ├── fase_01.tscn           herdada de fase_base.tscn
│   │   ├── fase_02.tscn           herdada de fase_base.tscn
│   │   └── fase_03.tscn           herdada de fase_base.tscn
│   └── ui/
│       ├── menu_principal.tscn
│       ├── hud.tscn
│       └── tela_captura.tscn
├── recursos/
│   ├── fases/fase_01.tres         FaseConfig — dados, zero lógica
│   ├── fases/fase_02.tres
│   └── fases/fase_03.tres
├── scripts/
│   ├── dominio/fase_config.gd     class_name FaseConfig extends Resource
│   ├── cripto/
│   │   ├── cifra.gd               interface comum
│   │   ├── cesar.gd
│   │   ├── vigenere.gd
│   │   └── sha256.gd              wrapper sobre HashingContext
│   ├── lexico/
│   │   ├── token.gd
│   │   ├── analisador_lexico.gd   AFD
│   │   ├── analisador_sintatico.gd parser recursivo descendente → AST
│   │   └── no_ast.gd
│   └── ia/
│       ├── navegacao.gd           wrapper de AStarGrid2D
│       ├── astar_referencia.gd    implementação didática (não-runtime)
│       └── diretor.gd             camada de informação imperfeita
├── tests/
└── docs/
    ├── decisoes/                  ADRs curtos, um por decisão relevante
    ├── gramatica.md               BNF + tabela de tokens + diagrama do AFD
    └── contrato-telemetria.md     exemplos reais de payload enviado
```

**Regra de ouro da herança:** se você precisar escrever a mesma linha de GDScript em
`fase_01.gd` e `fase_02.gd`, ela pertence a `fase_base.gd`. As cenas de fase idealmente têm
**zero script próprio** — apenas o `FaseConfig` atribuído e o `TileMapLayer` desenhado.

### `FaseConfig` (o "dado" que define uma fase)

```gdscript
class_name FaseConfig
extends Resource

@export var numero: int = 1                      # 1..4, casa com a constraint do banco
@export var titulo: String = ""
@export var algoritmo: String = "CESAR"          # CESAR | VIGENERE | SHA256 | AES
@export var verbos_permitidos: PackedStringArray = ["cifrar", "decifrar"]
@export var desafios: Array[DesafioConfig] = []
@export_range(1, 10) var vidas_iniciais: int = 3
@export_range(0.0, 200.0) var velocidade_cachorro: float = 45.0
@export_range(0.0, 30.0) var intervalo_replanejamento_s: float = 1.0
@export var briefing_pedagogico: String = ""     # texto exibido na entrada da fase
```

---

## 4. Restrições inegociáveis

Estas não são preferências. Violar qualquer uma quebra a conformidade ou a análise
estatística do trabalho.

1. **Nenhum dado pessoal sai do cliente.** Sem nome, e-mail, IP, identificador de máquina,
   caminho de arquivo do usuário, nada. O jogador é representado apenas por `id_sujeito`
   (UUID) recebido na configuração. Se o campo `payload` de um evento puder conter texto
   digitado, ele é truncado e sanitizado antes.
2. **O texto livre do terminal é truncado em 240 caracteres** antes de qualquer envio
   (`purrbytes.privacidade.limite-texto-livre` no back-end).
3. **IDs são gerados no cliente**: `id_sessao`, `id_evento`, `id_tentativa` são UUID v4
   gerados localmente. É isso que torna o reenvio idempotente após falha de rede.
4. **Dois relógios.** Todo evento carrega `ocorrido_em` em UTC ISO-8601 do relógio do
   cliente. O servidor grava o dele. Não tente corrigir, não use hora local.
5. **A sequência é monotônica por sessão**, começando em 0, sem lacunas. É o que permite
   detectar perda de pacote.
6. **O jogo nunca trava por causa do servidor.** Telemetria é assíncrona, enfileirada em
   disco e tolerante a falha por contrato. Se a API cair, o jogo continua jogável e a fila
   persiste em `user://`. Nenhuma chamada HTTP pode bloquear `_process` ou `_physics_process`.
7. **Os códigos de evento e de resultado são fixos**, ditados pelo banco. Não invente, não
   renomeie, não abrevie. Lista completa na seção 8.
8. **A chave de API embutida no cliente tem escopo `INGESTAO` (só escreve).** Ela vai vazar —
   é um binário distribuído. Trate como pública: nunca logue, nunca exiba na tela, e não
   guarde nada além dela no arquivo de configuração.

---

## 5. Marco 0 — Fundação

**Objetivo:** projeto que roda, com os serviços globais e a cena pai prontos, sem nenhuma
fase jogável ainda.

### Escopo

1. `project.godot` configurado conforme a seção 2. `InputMap` com `mover_cima`,
   `mover_baixo`, `mover_esquerda`, `mover_direita`, `abrir_terminal`, `pausar`.
2. Autoloads `ConfigJogo`, `Sessao`, `Telemetria`.
3. `ConfigJogo` lê `user://config.cfg` via `ConfigFile` com estes campos e defaults:
   `modo_telemetria = "MOCK"` (`MOCK` | `HTTP`), `url_api`, `chave_api`, `id_sujeito`,
   `versao_jogo`, `tamanho_lote = 50`, `intervalo_envio_s = 5.0`.
4. `Telemetria` implementa a fila: `registrar_evento()`, `registrar_tentativa()`,
   `iniciar_sessao()`, `encerrar_sessao()`, `descarregar()`. Persistência da fila em
   `user://fila_telemetria.json` a cada descarga e em `NOTIFICATION_WM_CLOSE_REQUEST`.
   Em modo `MOCK`, grava linhas JSON em `user://telemetria_mock.jsonl` e emite o sinal
   `evento_registrado` — é assim que os testes verificam sem servidor.
5. `fase_base.tscn` com a árvore completa: `TileMapLayer` do labirinto, `Jogador`,
   `Cachorro`, `Terminal` (CanvasLayer), `HUD`, `CameraJogador`, `Marcadores` (Node2D para
   pontos de saída e de desafio). O script `fase_base.gd` recebe um `FaseConfig` exportado e
   orquestra: carrega desafios, conecta sinais, emite `FASE_INICIADA` no `_ready` e
   `FASE_CONCLUIDA` / `FASE_ABANDONADA` na saída.
6. `TileSet` com uma custom data layer booleana chamada `solido`. É ela — e não o formato
   do tile — que define o que é parede para o A\* e para a colisão.
7. Menu principal navegável: Jogar, Telemetria (placeholder), Sair.

### Critérios de aceite

- [ ] `godot --headless --quit --path .` importa o projeto sem erro nem warning.
- [ ] `fase_base.tscn` **não** pode ser jogada diretamente e falha com mensagem clara se
      rodada sem `FaseConfig`.
- [ ] Iniciar e encerrar uma sessão em modo MOCK produz um `.jsonl` com
      `SESSAO_INICIADA` e `SESSAO_ENCERRADA`, sequência 0 e 1, `id_sessao` idêntico.
- [ ] Matar o processo com a fila cheia e reabrir: a fila é recuperada do disco.
- [ ] Nenhum `print()` solto; use uma função de log que respeita um nível configurável.

---

## 6. Marco 1 — Fase 1: Cifra de César, labirinto e A\*

**Objetivo pedagógico da fase:** o jogador entende deslocamento fixo do alfabeto e percebe,
na prática, que texto claro em trânsito é interceptável.

### Mecânica

O labirinto é a topologia de rede. O jogador transporta um pacote de dados até o nó de saída.
O cachorro farejador representa o interceptador. Regra central, herdada do protótipo e
validada nos casos TC-01 a TC-04 da monografia:

- Jogador em **texto claro** encostado pelo cachorro → interceptação: perde uma vida e
  pontuação, o pacote volta ao início. **Não é game over** — é custo pedagógico do erro.
- Jogador com **cifra ativa** (comando correto no terminal) → o cachorro não intercepta,
  simulando ofuscação. A cifra tem duração limitada, então o jogador precisa acertar de novo.
- Comando inválido → erro reportado no terminal, estado de proteção inalterado, e um pouco
  de ruído entregue ao Diretor (seção 7).

### Analisador léxico-sintático

Este é o componente que a banca questionou ("é realmente um motor léxico?"). Implemente com
rigor formal e com a separação das duas etapas visível no código e no resultado.

**Tabela de tokens**

| Token | Padrão | Exemplo |
|---|---|---|
| `VERBO` | palavra reservada da fase | `cifrar` |
| `IDENTIFICADOR` | `[a-z][a-z0-9_]*` | `pacote` |
| `NUMERO` | `[0-9]+` | `3` |
| `ATRIBUICAO` | `=` | `=` |
| `EOF` | fim da entrada | — |

**Gramática (BNF)**

```
<comando>       ::= <verbo> <lista_arg> EOF
<verbo>         ::= "cifrar" | "decifrar" | "hash" | "verificar" | "dica" | "status"
<lista_arg>     ::= <argumento> <lista_arg> | ε
<argumento>     ::= <par_chave> | IDENTIFICADOR | NUMERO
<par_chave>     ::= "chave" ATRIBUICAO ( IDENTIFICADOR | NUMERO )
```

**Pipeline:** normalizar (trim + minúsculas) → **AFD** produz `Array[Token]` → **parser
recursivo descendente** produz AST (`NoAst`) → **validação semântica** confere se o verbo
existe na fase, se a chave está na faixa e se o resultado resolve o desafio.

O `resultado` de cada tentativa é exatamente um destes, e o erro precisa cair na etapa certa:

`SUCESSO` · `ERRO_LEXICO` · `ERRO_SINTATICO` · `ERRO_SEMANTICO` · `TIMEOUT` · `ABANDONO`

Exemplo obrigatório de teste, retirado do caso TC-04 da monografia: `cyfrar pacote chave=3`
deve resultar em `ERRO_LEXICO` (o AFD não reconhece `cyfrar` como VERBO e o token cai como
IDENTIFICADOR onde a gramática exige VERBO — decida e **documente** de qual lado da fronteira
esse caso cai, e mantenha a decisão consistente entre código, testes e monografia).

### A\* no cachorro

- `Navegacao` (`scripts/ia/navegacao.gd`) encapsula `AStarGrid2D`:
  `region` derivada de `TileMapLayer.get_used_rect()`, `cell_size` do TileSet,
  `diagonal_mode = DIAGONAL_MODE_NEVER`, `default_compute_heuristic = HEURISTIC_MANHATTAN`.
  Células com custom data `solido = true` viram `set_point_solid()`.
- Manhattan com movimento em 4 direções e custo unitário é **admissível e consistente** —
  logo o A\* devolve caminho ótimo. Escreva isso em comentário: é a justificativa que a banca
  vai cobrar.
- Replanejamento por intervalo (`intervalo_replanejamento_s`), **não** a cada frame.
- **Depuração visual obrigatória:** uma tecla (`F3`) alterna a exibição do caminho calculado,
  desenhado com `_draw()` sobre o labirinto, mostrando nós expandidos e o caminho final. Essa
  visualização É a demo da IA para a banca (apontamento 7). Trate-a como funcionalidade, não
  como debug descartável.

### Critérios de aceite

- [ ] Testes unitários do César com vetores conhecidos, incluindo wrap-around (`z` + 3 = `c`),
      preservação de não-letras e chave 0 e 26.
- [ ] Testes do analisador cobrindo TC-01 a TC-04 mais, no mínimo, um caso por código de
      resultado.
- [ ] Teste que compara `AStarGrid2D` com `astar_referencia.gd` em 100 mapas aleatórios:
      mesmo custo de caminho em todos.
- [ ] Fase 1 jogável do início ao fim, com vidas, pontuação e retorno ao menu.
- [ ] Uma partida completa em modo MOCK emite, com sequência sem lacunas:
      `SESSAO_INICIADA`, `FASE_INICIADA`, `COMANDO_SUBMETIDO` (n), `ERRO_LEXICO` /
      `ERRO_SINTATICO` quando couber, `CACHORRO_DETECTOU`, `JOGADOR_CAPTURADO` quando
      ocorrer, `FASE_CONCLUIDA`, `SESSAO_ENCERRADA` — e uma `tentativa_comando` por comando
      digitado.

---

## 7. Marco 2 — Fase 2: Vigenère, Diretor de IA e economia de erro

**Objetivo pedagógico:** o jogador entende que a chave pode variar ao longo do texto, e que
isso torna a análise de frequência ineficaz.

### Vigenère

Chave alfabética em vez de numérica: `cifrar pacote chave=gato`. O mesmo analisador atende —
muda apenas `verbos_permitidos` e a validação semântica do `par_chave` no `FaseConfig`.
Se essa fase exigir alterar o parser, a generalização do Marco 1 está errada; conserte lá.

**Visualização comparativa** (Eixo 2 do planejamento): um painel lateral mostra, letra a
letra, o texto claro alinhado à chave repetida e ao texto cifrado, com o deslocamento
aplicado em cada posição destacado. Emite `CIFRA_DEMONSTRADA` quando aberto.

### Diretor de IA — informação imperfeita em dois níveis

Este é o diferencial técnico do projeto e precisa ser implementado exatamente com esta
semântica. Inspiração declarada: o sistema de dois cérebros de *Alien: Isolation*.

- O mapa é dividido em **regiões** (marcadores `Area2D` colocados na cena da fase, não no
  código).
- O `Diretor` **nunca recebe a posição exata do jogador**. Ele mantém uma crença
  probabilística sobre qual região o jogador ocupa, alimentada apenas por **pistas**:
  comando errado no terminal (pista forte), movimento em corredor aberto (pista fraca),
  tempo desde o último contato (decaimento), captura recente (reforço).
- O `Diretor` publica um alvo: o centro da região mais provável. O A\* leva o cachorro até
  lá. Chegando, entra um comportamento de **caça local** simples (varredura da região) até
  ganhar contato visual ou receber novo alvo.
- Se o cachorro tem linha de visão direta, aí sim persegue a posição real — e emite
  `CACHORRO_DETECTOU`. Ao perder, emite `CACHORRO_PERDEU` e volta ao alvo do Diretor.

**Enquadramento correto para a monografia:** isto **não** é dificuldade adaptativa. As regras
são fixas e idênticas para todos os participantes — condição necessária para a validade
interna do experimento. O que varia é o comportamento do jogador: quem erra menos gera menos
pistas e sofre menos pressão. Escreva isso em `docs/decisoes/0002-diretor-ia.md`, porque a
diferença entre "pressão determinística" e "dificuldade adaptativa" é exatamente o que separa
um experimento controlado de um confundidor metodológico.

Todos os parâmetros do Diretor (pesos das pistas, taxa de decaimento, período de
replanejamento) são `@export_range` no Inspector, nunca constantes no código.

### Economia de erro

- Vidas por fase (padrão 3, vindo do `FaseConfig`), pontuação com penalidade por captura e
  bônus por acerto de primeira.
- Captura → `tela_captura.tscn`, perde vida e pontos, reposiciona. Vidas zeradas → reinicia a
  fase, não expulsa do jogo.
- `dica` é um verbo válido: dá ajuda e **emite `DICA_SOLICITADA`**, que é indicador indireto
  de dificuldade no vetor de features (Eixo 4). Custa pontos, não vida.

### Critérios de aceite

- [ ] Vigenère com vetores conhecidos, incluindo chave mais curta que o texto e chave com
      caractere inválido.
- [ ] `fase_02.tscn` não tem script próprio — só `FaseConfig` e mapa.
- [ ] Teste do Diretor: dado um roteiro de pistas, a região-alvo escolhida é determinística e
      reproduzível com a mesma semente.
- [ ] O cachorro nunca converge para o jogador sem pista nem linha de visão (teste explícito
      contra "o cachorro sabe onde você está").

---

## 8. Marco 3 — Fase 3: SHA-256, telemetria em HTTP e instrumentação

**Objetivo pedagógico:** o jogador entende que hash é de mão única e serve para verificar
integridade, não para esconder e depois recuperar.

### SHA-256

- Use `HashingContext` com `HASH_SHA256`. Nunca implemente a primitiva.
- Verbos da fase: `hash <palavra>` e `verificar <palavra> <prefixo_hash>`.
- Mecânica: o pacote chega com um digest anexado; o jogador precisa verificar se o conteúdo
  bate antes de entregar. Entregar pacote adulterado custa vida — a lição é integridade.
- Painel visual mostrando o efeito avalanche: alterar um caractere muda o digest inteiro.
  Emite `CIFRA_DEMONSTRADA`.
- Teste com vetores oficiais (o digest de string vazia e o de `abc` são os canônicos).

### Migração da telemetria para HTTP

Agora o modo `HTTP` do `Telemetria` sai do papel, contra as rotas do contrato:

| Método | Rota | Quando |
|---|---|---|
| `POST` | `/v1/sessoes` | Abertura de sessão, idempotente pelo `id_sessao` do corpo |
| `POST` | `/v1/sessoes/{id}/eventos` | Lote de eventos |
| `POST` | `/v1/sessoes/{id}/tentativas` | Lote de tentativas de comando |
| `POST` | `/v1/sessoes/{id}/encerrar` | Encerramento |

Header `Authorization: Bearer <chave_api>`. A API responde **`202 Accepted`** — aceite
significa "recebi para processar", não "gravei". Trate `2xx` como sucesso, `4xx` como erro
permanente (descarta o lote e loga), `5xx` e falha de rede como transitório (retentativa com
**backoff exponencial e jitter**, teto configurável de tentativas, fila preservada).

**Como as rotas ainda não existem**, faça o desenvolvimento contra um servidor de eco local
(um script Python de 30 linhas em `tools/servidor_eco.py` basta) e deixe um teste de
integração que sobe esse eco, roda uma sessão e confere os corpos enviados campo a campo
contra a estrutura das tabelas. Documente os payloads reais em `docs/contrato-telemetria.md`
— é esse arquivo que o time do back-end vai usar para implementar o outro lado.

**Catálogo de eventos** (`codigo` exato, sem exceção):

```
SESSAO_INICIADA · SESSAO_ENCERRADA · SESSAO_ABANDONADA
FASE_INICIADA · FASE_CONCLUIDA · FASE_ABANDONADA
DICA_SOLICITADA · CIFRA_DEMONSTRADA
COMANDO_SUBMETIDO · ERRO_LEXICO · ERRO_SINTATICO
CACHORRO_DETECTOU · CACHORRO_PERDEU · JOGADOR_CAPTURADO
AMOSTRA_DESEMPENHO
```

**Campos de `tentativa_comando`:** `id_tentativa` (UUID), `id_sessao`, `fase` (1..4),
`desafio` (≤60 chars), `entrada_normalizada` (≤240 chars), `tokens` (array JSON de objetos
`{tipo, lexema, posicao}`), `resultado` (enum da seção 6), `codigo_erro` (≤40 chars, nulo em
caso de sucesso), `tempo_resposta_ms` (≥0, medido do foco no terminal até o Enter),
`numero_tentativa` (≥1, por desafio), `ocorrido_em`.

### Instrumentação de desempenho (Eixo 7)

`AMOSTRA_DESEMPENHO` a cada 30 segundos, com `Performance.get_monitor()`: FPS,
memória estática, objetos desenhados, e o tempo médio do último replanejamento de A\* em ms.
Esse último é o que permite afirmar, com número, que a IA cabe no orçamento de frame.

### Critérios de aceite

- [ ] SHA-256 validado contra vetores oficiais.
- [ ] Teste de integração com o servidor de eco: sessão completa, lotes respeitando o teto de
      500 eventos, sequência sem lacuna.
- [ ] Teste de resiliência: eco derrubado no meio da partida → jogo continua sem travar,
      fila cresce, eco volta, fila drena, **zero evento duplicado e zero perdido**.
- [ ] `docs/contrato-telemetria.md` com um exemplo real de cada corpo de requisição.
- [ ] As três fases jogáveis em sequência com progressão de vidas e pontuação.

---

## 9. Padrões de código

- **Tipagem estática em tudo**: parâmetros, retornos, variáveis, `Array[Tipo]`. Sem `Variant`
  fora de fronteira de serialização.
- `class_name` em toda classe reutilizável. `snake_case` para arquivos, funções e variáveis;
  `PascalCase` para classes e nós; `CONSTANTE_MAIUSCULA` para constantes.
- **Zero número mágico.** Toda constante de balanceamento é `@export` ou entra no
  `FaseConfig`. Se está no `.gd` e um game designer pode querer mudar, está no lugar errado.
- **Sinais para comunicação de baixo para cima, chamadas diretas para cima para baixo.** O
  jogador não conhece a fase; a fase escuta o jogador.
- Comentários e mensagens de UI em **português**; nomes de identificadores em português
  também, para casar com o vocabulário do banco e da monografia.
- Comentário explica **por que**, nunca o que — o código já diz o que.
- Nada de `get_node("../../..")`. Use `@onready`, `@export` de `NodePath` ou grupos.
- Commits em português, no imperativo, escopo por marco: `fase1: implementa AFD do terminal`.
- Ao terminar cada marco, atualize `docs/decisoes/` com o que foi decidido e por quê. Esses
  arquivos viram texto de monografia depois; escreva-os pensando nisso.

### Como trabalhar

1. Antes de escrever código novo, leia `CLAUDE.md` e os ADRs em `docs/decisoes/`.
2. Proponha o plano do marco e **espere confirmação** antes de implementar.
3. Implemente em incrementos que compilam. Rode `godot --headless --quit --path .` a cada
   incremento e o suite de testes ao fim de cada bloco.
4. Se um critério de aceite não puder ser cumprido como escrito, **pare e diga**, com a
   alternativa proposta. Não cumpra pela metade em silêncio.
5. Ao final do marco, entregue: o que ficou pronto, o que ficou pendente, quais decisões
   foram tomadas e o que precisa ser validado no editor manualmente (mapas, tiles,
   posicionamento de marcadores — isso não dá para fazer por código e precisa ser dito).

---

## 10. Fora de escopo (não implemente sem pedido explícito)

- Fase 4 (AES simplificado).
- Dashboard de telemetria — é aplicação separada, consome as visões `vw_resumo_sessao`,
  `vw_desempenho_fase`, `vw_features_ia` e `vw_ganho_aprendizado`.
- Qualquer tela que colete nome, e-mail ou consentimento. TCLE e cadastro de participante
  acontecem **fora do jogo**, pelas rotas de escopo `ADMINISTRACAO`.
- Contas, login, multiplayer, salvamento em nuvem.
- Godot RL Agents e treinamento de agentes: linha de trabalho separada, não entra no cliente.

---

## Apêndice — desvios do briefing já aplicados

Registrados aqui porque o documento acima é a referência e precisa continuar confiável.
Cada um tem justificativa completa no ADR indicado.

| Item do briefing | O que foi feito | Onde |
|---|---|---|
| `Time.get_datetime_string_from_system(true, true)` para timestamp | Substituído por `Relogio.agora_utc_iso()`: a chamada do briefing devolve `2026-08-21 23:04:16`, sem `T` e **sem fuso**, o que faria o `TIMESTAMPTZ` assumir o fuso do banco | ADR 0003 §6 |
| "sequência" listada em `sessao.gd` | Contador vive em `telemetria.gd` (escritor único, garante a restrição 5) | ADR 0003 §2 |
| Framework de testes GUT ou gdUnit4 em `addons/` | Suíte nativa (`extends SceneTree` + reflexão), zero addon, a pedido do orientando | ADR 0005 |
| `Array[DesafioConfig]` sem tipo definido | `DesafioConfig` criado como `Resource` de dado puro | ADR 0004 |
| InputMap com 6 ações | 7 ações: acrescentada `alternar_depuracao` (F3), que o Marco 1 exige para a demo do A\* | `tools/configurar_entrada.gd` |
