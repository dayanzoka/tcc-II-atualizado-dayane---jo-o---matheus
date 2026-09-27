# Conformidade com a monografia — estado do cliente

**Atualizado em:** 2026-09-25 · Referência: *Purr Bytes: jogo educacional para letramento
em segurança digital* (TCC I, Universidade Positivo, 2026).

Este documento existe para a defesa: para cada item declarado na monografia, o que o
cliente **tem hoje**, onde isso vive no código e como foi verificado. O que mudou de forma
está na seção [Desvios a defender](#desvios-a-defender), com o porquê.

---

## Objetivos específicos (seção 1.5.2)

| Objetivo | Estado no cliente | Onde |
|---|---|---|
| Levantar requisitos funcionais e não funcionais | ✅ rastreados abaixo, um por um | este documento |
| Design de nível 0 (arquitetura cliente-servidor) | ✅ lado cliente: fila, lote e contrato REST documentados | `autoload/telemetria.gd`, `docs/contrato-telemetria.md` |
| Interface gráfica 2D e mecânicas de interação | ✅ | `cenas/`, `scripts/` |
| Back-end com criptografia e API REST de telemetria | ⏳ **fora deste repositório** (`Morc3go/prototipo`); o cliente já fala o contrato (modo HTTP) | `scripts/telemetria/transporte_http.gd` |
| Analisador léxico para validar os comandos | ✅ AFD + parser recursivo descendente + validação semântica | `scripts/lexico/`, ADR 0006, `docs/gramatica.md` |

## Requisitos funcionais (seção 4.1.1)

| Requisito | Estado | Onde / como verificar |
|---|---|---|
| Inserir comandos por interface de análise léxica para ações de defesa | ✅ terminal (`T`); vigia de **cifra** exige `cifrar <palavra> chave=<k>` ou `verificar`, validado por AFD → parser → semântica | `cenas/base/terminal.tscn`, `FaseBase._analisar_comando`, `tests/teste_vigia_de_cifra.gd` |
| Simular rotas de pacotes e comportamento dinâmico de ameaças | ✅ labirinto gerado (topologia), cachorros com A\* (`AStarGrid2D`), patrulha e linha de visão; `F3` desenha a rota | `scripts/ia/navegacao.gd`, `scripts/geracao/gerador_de_mapa.gd`, `tests/teste_astar.gd` |
| Registrar tempo de resolução, taxa de acerto e taxa de erro | ✅ por resposta (`tentativa_comando.tempo_resposta_ms`, `resultado`), por partida e por fase (`id_fase`) | `autoload/telemetria.gd`, `scripts/telemetria/resumo_telemetria.gd`, ADR 0014 |
| Aplicar visualmente cifras e hashing como proteção | ✅ acerto mostra a transformação letra a letra no terminal; `F4` abre o painel de demonstração (César/Vigenère alinhado à chave; SHA-256 com efeito avalanche) | `FaseBase._explicar_no_terminal`, `cenas/base/painel_cifra.tscn`, ADR 0008 |

## Requisitos não funcionais (seção 4.1.2)

| Requisito | Estado | Observação |
|---|---|---|
| Pixel art 2D, fluido em hardware escolar | ✅ | gato e cachorros animados (`AnimatedSprite2D` + `SpriteFrames`), filtro Nearest, renderizador Mobile, 640×360; `AMOSTRA_DESEMPENHO` a cada 30 s mede FPS, memória e custo do A\* — ADR 0013 |
| Comunicação assíncrona via API REST/JSON | ✅ lado cliente | `HTTPRequest`, fila em disco, lote, backoff com jitter; nunca bloqueia o jogo — ADR 0003/0009 |
| Sem dados de identificação pessoal | ✅ | só UUIDs (`id_sujeito`, `id_sessao`, `id_fase`); texto livre truncado em 240; chave de API nunca exibida |
| Arquitetura modular; nova fase com baixo esforço, por matriz de dados | ✅ | fase é um JSON (mapa por semente + listas de vigias e perguntas) que vira `FaseConfig`; `fase_base.tscn` é a única cena de fase; o editor cria fases sem código — ADR 0004/0011/0012 |

## Casos de teste estrutural (Quadro 1)

Os quatro rodam na suíte automatizada contra a **fase de exemplo**, em
`tests/teste_casos_monografia.gd` — um teste por linha do quadro, com a condição de
entrada e o resultado esperado da monografia.

| Caso | Resultado esperado na monografia | Verificação |
|---|---|---|
| TC-01 Colisão estática | o personagem não atravessa parede | jogador empurrado contra a parede por 60 quadros de física real não passa do limite da célula; a colisão vem da camada `solido` do `TileSet`, a mesma que o A\* lê |
| TC-02 Interceptação em texto claro | pausa e alerta de dados vazados | contato sem proteção: perde uma vida (não é game over), a ação congela (controle e cachorros param), tela de captura e `JOGADOR_CAPTURADO` |
| TC-03 Passagem segura criptografada | analisador valida `cifrar`; o personagem passa ileso | `cifrar senha chave=3` → `SUCESSO`; o contato com o vigia de César não custa vida |
| TC-04 Falha léxica (`cyfrar`) | rejeição, texto claro mantido, registro de erro de sintaxe | `cyfrar` tokeniza como IDENTIFICADOR e o parser rejeita por faltar VERBO → `ERRO_SINTATICO` (tentativa e evento); proteção não ativa |

## Protótipos (Figuras 5 a 7)

| Figura | Tela no jogo | Diferença |
|---|---|---|
| 5 — Menu (jogar, telemetria, sair) | `cenas/ui/menu_principal.tscn` | "jogar" virou **escolher fase**, e entraram **criar fase** e **subir fase** (ferramenta de autoria) |
| 6 — Labirinto e motor léxico | `cenas/base/fase_base.tscn` + terminal | o terminal abre por cima do labirinto com `T` e pausa o jogo, em vez de ocupar uma faixa fixa da tela |
| 7 — Dashboard de telemetria | `cenas/ui/dashboard_telemetria.tscn` | além de acertos × erros, tempo por fase e exportar JSON: **fases jogadas**, detalhe por fase e média só das fases escolhidas — ADR 0014 |

## Arquitetura (seção 4.2)

| Item | No cliente |
|---|---|
| 4.2.1 Cena pai e cenas filhas | `fase_base.tscn` concentra a lógica (terminal, telemetria, IA, HUD); a fase é dado (`FaseConfig`). A herança de cenas continua disponível, mas as fases de autoria nem precisam de cena própria — a configuração nasce do JSON |
| 4.2.2 Renderização espacial | `TileMapLayer` + `TileSet` com custom data `solido`; mapa e navegação derivam do mesmo dado |
| 4.2.3 Analisador léxico do terminal | normalização (trim + minúsculas) → AFD gera tokens → parser recursivo descendente gera AST → validação semântica; o erro cai na etapa certa (`ERRO_LEXICO` / `ERRO_SINTATICO` / `ERRO_SEMANTICO`) |

---

## Desvios a defender

### 1. Fases fixas → ferramenta de autoria

A monografia descreve fases criadas por herança de cena. O jogo evoluiu para uma
**ferramenta de autoria**: o professor cria a fase no editor (vigias, perguntas, mapa), e o
jogo gera um labirinto sempre solucionável a partir de uma semente. César, Vigenère e
SHA-256 continuam no jogo como **tipos de vigia**: cada vigia de cifra vira um desafio do
terminal. Isso atende o mesmo RNF (fase nova sem código) de forma mais forte: nem cena nova
é preciso. ADR 0011/0012/0015.

### 2. Dois tipos de comando no terminal

- **Vigia de cifra** (César, Vigenère, SHA-256): o comando passa por AFD, parser e
  validação semântica, e a proteção vem da cifra real. É o caminho do TC-03 e do TC-04.
- **Vigia de comando livre** (ex.: `trocar senha`): o professor escreve uma frase de
  conduta, que é comparada **exatamente**, antes do analisador, porque uma frase livre não
  cabe na gramática formal do terminal. Ela entra na telemetria do mesmo jeito (tempo,
  resultado).

### 3. Anonimato: UUID em vez de nome e e-mail

O dicionário de dados (4.4) tem `JOGADOR(nome, email)`. O cliente só conhece `id_sujeito`
(UUID recebido na configuração): nome, e-mail e TCLE ficam fora do jogo, do lado da
pesquisa. Atende o RNF de anonimato de forma mais rigorosa, e `PARTIDA` /
`EVENTO_TELEMETRIA` continuam representáveis (`id_sessao`, `FASE_INICIADA` →
`FASE_CONCLUIDA`, `tentativa_comando`).

### 4. `id_fase` como identidade da fase

O banco nasceu com `CHECK (fase BETWEEN 1 AND 4)`. Numa ferramenta de fases livres isso
perderia dado, então todo evento carrega `id_fase` (UUID gravado no arquivo da fase) e o
número vai só como legado. Contrato em `docs/contrato-telemetria.md`, seção 0.

### 5. Tecnologia do protótipo

A seção 6.1 cita um protótipo em JavaScript; o cliente atual é Godot 4 (GDScript tipado),
como a seção 2.1 especifica. Os casos TC-01 a TC-04 foram refeitos sobre ele.

---

## Pendências para o TCC II

1. **Back-end.** As rotas REST não existem em produção; o cliente foi validado contra
   `tools/servidor_eco.py`. Falta decidir a stack (a monografia cita Java/Kotlin + JCA) e
   alinhar a constraint de número de fase com o `id_fase`.
2. **Diretor de IA nas fases de autoria.** O Diretor (informação imperfeita, ADR 0002)
   só liga quando a fase declara regiões, e as fases de autoria não declaram — nelas o
   cachorro persegue por linha de visão e patrulha. Não é requisito da monografia, mas é
   diferencial citado no planejamento.
3. **Rotas do A\* na telemetria.** A seção 2.4 cita "rotas calculadas no algoritmo A\*"
   entre os dados coletados. Hoje vai o **custo** do replanejamento
   (`AMOSTRA_DESEMPENHO`), não a rota.
4. **Arte dos tiles** do labirinto ainda é placeholder (personagens já têm pixel art).
5. **Validação com usuários** (pré/pós-teste, análise estatística) acontece fora do jogo;
   antes da coleta, jogar uma partida completa na máquina da escola e conferir o painel de
   diagnóstico.
