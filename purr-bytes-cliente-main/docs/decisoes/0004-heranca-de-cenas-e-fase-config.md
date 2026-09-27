# ADR 0004 — Herança de cenas e fase como dado

**Marco:** 0 · **Data:** 2026-08-21 · **Situação:** aceita

## Contexto

O requisito não funcional mais importante da monografia é *"arquitetura modular
de alta manutenibilidade, permitindo a adição de novas fases com baixo esforço de
codificação, através do uso de matrizes de dados"*. Esse requisito é fácil de
declarar e fácil de quebrar: basta uma fase precisar de "só um ajustezinho" no
script para virar quatro scripts quase iguais.

## Decisão

**Uma cena pai com toda a lógica; fases são cenas herdadas que só carregam
dados.**

- `cenas/base/fase_base.tscn` + `fase_base.gd` concentram o ciclo da fase:
  validação, telemetria de `FASE_INICIADA`/`FASE_CONCLUIDA`/`FASE_ABANDONADA`,
  captura, terminal, câmera, HUD.
- `cenas/fases/fase_0N.tscn` (Marcos 1 a 3) são **cenas herdadas** que trazem
  dois dados: o `FaseConfig` atribuído no Inspector e o labirinto desenhado no
  `TileMapLayer`. Idealmente **zero script próprio**.
- `FaseConfig` (`Resource` salvo em `.tres`) carrega número, título, algoritmo,
  verbos permitidos, desafios, vidas, velocidade do cachorro, intervalo de
  replanejamento, duração da cifra, penalidades e — desde já — os parâmetros do
  Diretor de IA do Marco 2.

Critério objetivo de falha da arquitetura, registrado para a defesa: **se a fase
4 (AES) exigir um campo novo em `FaseConfig` que não seja um valor, ou um script
próprio, a generalização falhou** — e o conserto é em `fase_base.gd`, não na
fase.

### `FaseConfig` se valida

`problemas()` devolve a lista de incoerências: número fora de 1..4 (que a
constraint do banco recusaria), fase sem desafio, verbo esperado fora de
`verbos_permitidos`, identificador repetido ou acima de `VARCHAR(60)`, faixa de
chave invertida. `fase_base.gd` chama isso no `_ready` e, se houver problema,
mostra a mensagem **na tela** e desliga o processamento.

Por que na tela e não só no log: `fase_base.tscn` aberta direto no editor (F6)
precisa falhar de forma óbvia. Uma cena pai que roda meio funcionando é a receita
para alguém desenhar um mapa dentro dela por engano.

### Zero número mágico

Toda constante de balanceamento é `@export`/`@export_range` no `FaseConfig` ou no
nó, nunca literal no `.gd`. Vale inclusive para os parâmetros do Diretor, que o
`CLAUDE.md` exige ajustáveis pelo Inspector.

### `DesafioConfig`

O briefing referencia `Array[DesafioConfig]` sem definir o tipo. Ele foi criado
como `Resource` de dado puro: identificador (que vira `tentativa_comando.desafio`
e por isso é limitado a 60 caracteres), enunciado, texto claro, chave esperada,
verbo esperado, resposta esperada, dica e pontuação. Um campo único de chave em
`String` atende César (`"3"`), Vigenère (`"gato"`) e SHA-256 (vazio).

### Comunicação

Sinal de baixo para cima, chamada de cima para baixo. `Jogador` e `Cachorro` não
conhecem a fase — emitem sinais. A HUD escuta o autoload `Sessao` em vez de ser
atualizada pela fase, o que permite uma segunda tela mostrar o mesmo estado sem
acoplamento novo.

## Consequências

- Fases novas custam um `.tres` e um mapa desenhado.
- A lógica de fase tem um só lugar para ser lida, corrigida e defendida.
- O preço é indireção: entender uma fase exige abrir o `.tres` e o `fase_base.gd`
  juntos. Aceitável, e mitigado por `FaseConfig.problemas()` reclamar cedo.
