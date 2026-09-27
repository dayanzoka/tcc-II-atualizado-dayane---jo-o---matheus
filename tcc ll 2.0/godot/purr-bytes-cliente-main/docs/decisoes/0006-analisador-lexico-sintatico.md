# ADR 0006 — Fronteira entre o analisador lexico e o sintatico

**Marco:** 1 · **Data:** 2026-08-22 · **Situação:** aceita

## Contexto

A banca questionou, no protótipo anterior, se o analisador do terminal era "um
motor léxico de verdade" (apontamento 5). A resposta tem que aparecer no
código como duas etapas realmente separadas — cada uma com sua própria
estrutura de dados de entrada/saída — e não como um único `if` disfarçado de
gramática. O caso de teste obrigatório da monografia, TC-04
(`cyfrar pacote chave=3`), é o que força a decisão a ficar explícita: de qual
lado da fronteira cai uma palavra reservada mal escrita?

## Decisão

**O AFD (`scripts/lexico/analisador_lexico.gd`) só sabe formar tokens a partir
do alfabeto da linguagem. Ele não sabe o que é um comando válido.**

- A tabela de palavras reservadas que o AFD reconhece como `VERBO`
  (`AnalisadorLexico.VERBOS_DA_GRAMATICA`) é a lista **global** da BNF da seção
  6 do `CLAUDE.md` — `cifrar`, `decifrar`, `hash`, `verificar`, `dica`,
  `status` — e não `FaseConfig.verbos_permitidos`. Essa segunda lista é
  **semântica** (o que esta fase aceita) e vive na terceira etapa do pipeline,
  não na primeira.
- Uma palavra que bate com `[a-z][a-z0-9_]*` mas não está na tabela de verbos
  — como `cyfrar` — forma um token `IDENTIFICADOR` perfeitamente válido. O AFD
  não erra aqui: ele reconheceu um lexema legítimo da linguagem.
- **TC-04 é, portanto, `ERRO_SINTATICO`, não `ERRO_LEXICO`.** O erro aparece
  quando `AnalisadorSintatico` exige um `VERBO` na primeira posição
  (`<comando> ::= <verbo> <lista_arg> EOF`) e encontra um `IDENTIFICADOR` no
  lugar. `ERRO_LEXICO` fica reservado para caractere que **nenhuma** transição
  do automato aceita (ex.: `!`, acentuação, maiúsculas não normalizadas antes
  do AFD).
- O parser (`scripts/lexico/analisador_sintatico.gd`) é recursivo descendente,
  uma função por produção da BNF, e devolve uma `NoAst` ou o token exato que
  quebrou a derivação mais o que era esperado ali — é essa informação que vira
  `codigo_erro` fixo (`caractere_invalido` / `token_inesperado`) em
  `tentativa_comando`.
- A palavra `"chave"` não é reservada na tabela de tokens: ela chega como
  `IDENTIFICADOR` comum. Quem decide se abre a produção `<par_chave>` é o
  parser, com **um token de lookahead** (o próximo tem que ser `ATRIBUICAO`).
  Isso é deliberado — reconhecer `chave=` é gramática, não léxico; se o AFD
  tentasse resolver essa ambiguidade, a fronteira entre as duas etapas deixaria
  de existir de fato, mesmo que existisse em arquivos separados.

### Terceira etapa: semântica

`scripts/lexico/resolvedor_comando.gd` só roda depois que léxico e sintático
passam. É o único lugar que conhece `FaseConfig` e o desafio corrente:
verbo permitido nesta fase, chave dentro de
`faixa_chave_minima..faixa_chave_maxima`, e se a chave resolve o desafio
ativo. Uma chave sintaticamente válida e dentro da faixa, mas que não resolve
o desafio (ex.: `cifrar pacote chave=7` quando o esperado é `3`), também cai
em `ERRO_SEMANTICO` — não existe um código separado para "chave errada" na
constraint `ck_tentativa_resultado` do banco, e "estrutura válida, significado
inválido" é a leitura mais próxima que a enumeração fixa permite.

### `codigo_erro` é vocabulário fixo, não texto livre

Cada erro produz um código curto e estável
(`caractere_invalido`, `token_inesperado`, `verbo_nao_permitido`,
`sem_desafio_ativo`, `verbo_nao_esperado_pelo_desafio`, `chave_ausente`,
`chave_invalida`, `chave_fora_da_faixa`, `chave_incorreta`,
`algoritmo_nao_suportado_nesta_fase`, `verbo_nao_implementado_nesta_fase`), em
vez de embutir a posição ou o caractere ofensivo na string. Os `tokens` da
tentativa já carregam posição e lexema — duplicar isso em `codigo_erro`
(VARCHAR(40)) só arriscaria truncamento e atrapalharia agrupar por tipo de
erro no Eixo 1.

## Consequências

- O mesmo `AnalisadorComando`/`AnalisadorSintatico` atende Vigenère no Marco 2
  sem alteração: só muda `FaseConfig.verbos_permitidos` e a validação
  semântica da chave (numérica vira alfabética). Se Vigenère exigir tocar o
  parser, esta ADR está sinalizando que a generalização falhou — critério
  de aceite explícito do planejamento do Marco 2 (`CLAUDE.md`).
- `tests/teste_analisador_lexico.gd` e `tests/teste_analisador_sintatico.gd`
  testam as duas etapas isoladamente (tokens prontos entrando no parser, sem
  passar pelo AFD); `tests/teste_analisador_comando.gd` testa o pipeline dos
  dois juntos, incluindo o TC-04 ponta a ponta;
  `tests/teste_resolvedor_comando.gd` testa a etapa semântica isolada, com um
  `FaseConfig`/`DesafioConfig` construídos em memória.
