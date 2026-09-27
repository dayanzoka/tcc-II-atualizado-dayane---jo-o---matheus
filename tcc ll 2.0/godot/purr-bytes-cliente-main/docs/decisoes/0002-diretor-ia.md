# ADR 0002 — Diretor de IA: informação imperfeita por região

**Marco:** 2 · **Data:** 2026-08-23 · **Situação:** aceita

## Contexto

A seção 7 do `CLAUDE.md` pede um cachorro que **nunca** recebe a posição
exata do jogador, inspirado no sistema de dois cérebros de *Alien:
Isolation*: um "cérebro" percebe (linha de visão), o outro só acredita
(crença por região, atualizada por pistas). O ponto de honestidade
metodológica mais importante da fase: **isto não é dificuldade adaptativa**.
As regras — pesos das pistas, taxa de decaimento, intervalo de decisão — são
fixas e idênticas para todos os participantes, ajustáveis só pelo Inspector
(nunca por código), e nada aqui reage ao desempenho do jogador de forma
diferenciada. O que varia é só o comportamento do próprio jogador: quem erra
menos no terminal gera menos pistas fortes, e por isso sofre menos pressão —
mas a REGRA que traduz erro em pressão é a mesma para todo mundo. Confundir
essas duas coisas na monografia transformaria um experimento controlado num
confundidor metodológico.

## Decisão

### Garantia estrutural, não de convenção

`scripts/ia/diretor.gd` (`Diretor`) não tem **nenhum** parâmetro de método
tipado como posição do jogador. Toda entrada é uma referência a um nó
`Area2D` já existente na cena (uma "região") ou um evento sem posição
nenhuma (decaimento por tempo). Quem observa overlap de `Area2D` e decide
"o jogador está nesta região agora" é `FaseBase` — o `Diretor` só agrega o
que chega. Isso não é uma promessa em comentário: é impossível o `Diretor`
vazar posição exata porque ele nunca a recebe.

### Crença como distribuição normalizada, sem aleatoriedade

`_crenca: Dictionary` mapeia cada região a um peso; toda pista soma um peso
fixo (`FaseConfig.peso_pista_comando_errado/movimento/captura`) e o dicionário
é renormalizado para somar 1.0. `regiao_mais_provavel()` é a de maior peso;
empate cai na primeira região da lista (ordem de filhos da cena —
determinístico). **Não há gerador de números aleatórios em nenhum ponto.**
Isso cumpre o critério de aceite ("dado um roteiro de pistas, a região-alvo
escolhida é determinística e reproduzível") sem precisar de semente: o mesmo
roteiro de chamadas produz sempre o mesmo resultado, porque não há nada
estocástico para "semear". `tests/teste_diretor.gd` roda o mesmo roteiro em
dois `Diretor` frescos e confere que as transições de alvo saem idênticas.

### Três pistas, três pesos, um decaimento

| Pista | Método | Peso (`FaseConfig`) | Natureza |
|---|---|---|---|
| Comando errado no terminal | `pista_comando_errado(regiao)` | `peso_pista_comando_errado` (padrão 1.0) | forte — o jogador denunciou onde está ao errar |
| Movimento observado | `pista_movimento(regiao)` | `peso_pista_movimento` (padrão 0.25) | fraca — só "passou por aqui" |
| Captura recente | `pista_captura(regiao)` | `peso_pista_captura` (padrão 2.0, novo campo) | reforço — é um evento físico, não inferência |
| Nenhuma (tempo passa) | `decair(delta_s)` | `decaimento_crenca_por_s` | a crença relaxa de volta para a distribuição uniforme |

`pista_movimento` dispara **uma vez por entrada na região** (borda de subida
do `Area2D.body_entered`), não a cada quadro em que o jogador permanece
dentro dela — reforçar continuamente equivaleria, com tempo suficiente, a
entregar a posição quase exata, o que anularia a própria premissa da
informação imperfeita.

`decair()` roda num `Timer` próprio (`intervalo_decisao_diretor_s`),
**separado** do timer de replanejamento do A\* (`intervalo_replanejamento_s`):
são cadências pedagógicas diferentes — o Diretor "pensa" num ritmo, o
cachorro recalcula rota no seu.

### Alvo do A\*: linha de visão sempre vence

`FaseBase._alvo_de_perseguicao()` decide, a cada replanejamento:

1. `Cachorro.tem_linha_de_visao(jogador)` verdadeiro → alvo é a posição real.
   O cachorro "viu" o jogador; fingir que não sabe seria artificial, e é
   exatamente o gatilho de `CACHORRO_DETECTOU`.
2. Sem linha de visão e há `Diretor` (a fase tem regiões) → alvo é
   `Diretor.regiao_mais_provavel()`, com uma varredura simples de pontos ao
   redor do centro quando o cachorro já chegou lá (`_alvo_de_varredura`) —
   a "caça local" da seção 7, resetada sempre que o Diretor muda de alvo.
3. Sem linha de visão e sem `Diretor` (fase sem nenhuma região em
   `Marcadores/Regioes` — o caso de `fase_01.tscn`) → alvo é a posição real,
   preservando **exatamente** o comportamento do Marco 1
   (docs/decisoes/0007, decisão 1). Isso não é acidente: `fase_01.tscn`
   continua sem regiões de propósito, e `tests/teste_fase_01_integracao.gd`
   segue verde sem alteração.

### Regiões são dado de cena, não de código

`Marcadores/Regioes` já existia como `Node2D` vazio desde o Marco 0
(placeholder deliberado). `FaseBase._configurar_diretor()` só faz
`get_children()` sobre ele e filtra `Area2D` — quantas regiões existirem,
onde estiverem, é decisão de quem monta `cenas/fases/fase_0N.tscn`, nunca uma
constante em `diretor.gd`. `fase_02.tscn` tem 4 regiões geradas por
`tools/gerar_fase_02.gd` cobrindo os quadrantes do labirinto; uma fase futura
poderia ter 2, 6, ou nenhuma.

## Consequências

- `tests/teste_diretor.gd` testa o `Diretor` isolado (sem cena, sem
  `FaseBase`): `Area2D.new()` fora de qualquer `SceneTree` já expõe
  `global_position`, que é a única coisa que o `Diretor` lê deles.
- `tests/teste_fase_02_integracao.gd` prova o critério "nunca converge sem
  pista nem visão": com o cachorro longe e nenhuma pista dada, o jogador anda
  livremente dentro da mesma região e o alvo do A\* não se move — só uma
  pista real (cruzar de região, errar comando, ser capturado) ou linha de
  visão direta muda o alvo.
- Se uma fase futura precisar de um comportamento de "caça local" mais
  elaborado que a varredura de 5 pontos atual, o lugar de crescer isso é
  `FaseBase._alvo_de_varredura` — o `Diretor` continua não sabendo nada sobre
  movimento, só sobre crença.
