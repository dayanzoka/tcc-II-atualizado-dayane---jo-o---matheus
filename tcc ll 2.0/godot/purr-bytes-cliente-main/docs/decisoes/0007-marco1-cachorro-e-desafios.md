# ADR 0007 — Cachorro do Marco 1 e progressão de desafios

**Marco:** 1 · **Data:** 2026-08-22 · **Situação:** aceita

## Contexto

O `CLAUDE.md` especifica o Diretor de IA (informação imperfeita, crença por
região) na seção 7, **Marco 2**. O Marco 1 precisa de um cachorro funcional
antes disso existir, e os critérios de aceite do Marco 1 já exigem
`CACHORRO_DETECTOU` numa partida completa. Também precisa de uma forma de
escolher "qual desafio está ativo" — `FaseConfig.desafios` é uma lista, mas
nada no briefing diz como o terminal decide contra qual desafio validar um
comando `cifrar`/`decifrar`.

## Decisões

### 1. Sem Diretor, o cachorro persegue a posição real do jogador

No Marco 1 não existe crença nem região: `Navegacao.calcular_caminho()` recebe
a posição real do jogador a cada replanejamento
(`FaseBase._replanejar_caminho_do_cachorro`, por
`FaseConfig.intervalo_replanejamento_s`, nunca por quadro). Isso **não**
antecipa o Marco 2 por acidente — é exatamente o comportamento de "informação
perfeita" que o Diretor vai substituir; o teste do Marco 2
(`"o cachorro nunca converge para o jogador sem pista nem linha de visão"`)
só faz sentido porque o Marco 1 é o ponto de partida sem essa restrição.

### 2. `alcance_deteccao_cachorro`: linha de visão controla só a telemetria de detecção

Adicionado a `FaseConfig` (zero número mágico) e aplicado ao `Cachorro` em
`FaseBase._ready()`. `Cachorro.tem_linha_de_visao(alvo_global)` usa um
`RayCast2D` nativo (`collision_mask = 1`, a mesma camada física do
labirinto) mais uma checagem de distância — ferramenta nativa, sem raycasting
manual.

No Marco 1 este método **não decide o alvo do A\*** (que já é sempre a posição
real, decisão 1). Ele só controla a borda de subida/descida de
`CACHORRO_DETECTOU`/`CACHORRO_PERDEU`, checada a cada `_physics_process` (não
por intervalo — a detecção precisa ser tão responsiva quanto o jogo, mesmo com
o replanejamento do A\* mais lento). Isso deixa a peça pronta para o Marco 2:
quando o Diretor existir, a mesma linha de visão passa a decidir *entre*
perseguir a posição real (visão direta) *ou* o alvo do Diretor (sem visão) —
só a função que produz o alvo do A\* muda; a peça de percepção já está no
lugar certo.

### 3. Desafios resolvidos em ordem fixa, um ativo por vez

`FaseBase` guarda `_indice_desafio` e resolve `FaseConfig.desafios` em ordem:
o desafio corrente é `configuracao.desafios[_indice_desafio]`, e
`ResolvedorComando` só valida `cifrar`/`decifrar` contra ele.
`_avancar_desafio()` incrementa o índice e reseta `_numero_tentativa_do_desafio`
quando o desafio corrente é resolvido. Não existe "escolher desafio" pelo
terminal — é a leitura mais simples que atende César (Marco 1) e Vigenère
(Marco 2) sem exigir campo novo em `FaseConfig` ou `DesafioConfig`. Se uma
fase futura precisar de desafios paralelos ou fora de ordem, o lugar de
resolver isso é aqui, não no analisador.

### 4. `numero_tentativa` só conta tentativas reais do desafio corrente

`status` e `dica` não incrementam `_numero_tentativa_do_desafio`: só um
`cifrar`/`decifrar` cujo verbo bate com `DesafioConfig.verbo_esperado`
consome uma tentativa (resolvendo ou não). Isso é o que faz
`pontos_acerto_de_primeira` significar "acertou de primeira" de verdade, e não
"foi o primeiro comando digitado, mesmo que fosse `status`".

### 5. `ABANDONO`: gatilho real é abandonar a fase com desafio ativo

`FaseBase.abandonar()` registra uma `tentativa_comando` com resultado
`ABANDONO` para o desafio corrente, se houver um, antes de emitir
`FASE_ABANDONADA`. É o único caminho de jogo real deste marco que produz esse
código — cobre o critério de aceite ("um caso por código de resultado") com
comportamento genuíno, não com uma tentativa fabricada só para o teste passar.

### 6. `TIMEOUT` — pendência assumida, não implementada

**Nenhum critério de aceite do Marco 1 é cumprido pela metade em silêncio**
(seção 9 do `CLAUDE.md`), então isto fica registrado aqui: não existe, na
seção 6 nem em `FaseConfig`, um campo de prazo por desafio (`tempo_limite_s`
ou equivalente). Inventar um agora seria adicionar mecânica de jogo não
especificada. `CatalogoResultados.TIMEOUT` existe na enumeração e é aceito
por `Telemetria.registrar_tentativa()` (testado como plumbing), mas nenhum
caminho de jogo do Marco 1 o produz. Se a fase precisar de prazo por desafio,
é uma decisão de design pendente para quem define o balanceamento — a
consequência de código é pequena (`FaseConfig` ganha um campo, `FaseBase`
ganha um `Timer` por desafio) mas é uma decisão de jogo, não de arquitetura.

### 7. Depuração visual do A\* (F3): só o caminho final, não os "nós expandidos"

`AStarGrid2D` não expõe pela API pública quais células entraram no conjunto
fechado durante a última busca — só o caminho resultante
(`get_point_path`). A implementação didática que expõe isso
(`scripts/ia/astar_referencia.gd`) é **explicitamente vetada para uso em
runtime** pela seção 2 do `CLAUDE.md`. `FaseBase._draw()` (tecla F3) desenha
o caminho calculado — linha e pontos de passagem — mas não os nós expandidos
pedidos no apontamento 7. Alternativa não tomada, e por quê: rodar o
algoritmo de referência em paralelo só para alimentar o overlay de depuração
usaria o código didático em runtime, contradizendo a própria regra que o
criou.

## Consequências

- `tests/teste_fase_01_integracao.gd` monta `cenas/fases/fase_01.tscn` de
  verdade e percorre o pipeline inteiro (léxico → sintático → semântico → IA
  → economia de vidas/pontos), conferindo a sequência de eventos sem lacuna e
  uma `tentativa_comando` por comando digitado — é o teste que valida estas
  sete decisões juntas.
- Ao chegar no Marco 2, dois pontos exigem atenção por causa desta ADR: (a) o
  alvo do A\* passa a vir do Diretor quando não há linha de visão — a função
  que hoje sempre devolve `jogador.global_position` em
  `FaseBase._replanejar_caminho_do_cachorro` precisa ganhar essa ramificação;
  (b) se `TIMEOUT` for necessário, definir o campo de prazo em `FaseConfig`
  antes de tocar em `FaseBase`.
