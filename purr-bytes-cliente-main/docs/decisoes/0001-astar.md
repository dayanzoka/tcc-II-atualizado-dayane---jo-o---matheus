# ADR 0001 — Duas implementações de A\*

**Marco:** 1 · **Data:** 2026-08-22 · **Situação:** aceita

## Contexto

A seção 2 do `CLAUDE.md` coloca o projeto entre duas exigências que parecem
se opor: "prefira sempre a ferramenta nativa da engine à implementação
artesanal" (regra geral de todo o projeto) e o apontamento 14 da banca —
"justificar o uso do A\* com explicação do algoritmo", que só se cumpre de
verdade mostrando o algoritmo por dentro: fila de prioridade, `g`/`h`/`f`,
conjuntos aberto e fechado.

Usar só `AStarGrid2D` responde "o jogo roda", mas não responde "vocês sabem
como o A\* funciona" — a implementação fica dentro do motor, opaca. Reescrever
o A\* à mão para rodar no jogo quebraria a primeira regra sem necessidade: a
engine já resolve pathfinding em grade corretamente e com desempenho que uma
implementação amadora dificilmente igualaria.

## Decisão

**Duas implementações, com papéis explicitamente diferentes — nunca a mesma
função fazendo os dois papéis.**

1. **`scripts/ia/navegacao.gd` (`Navegacao`) — é o que roda o jogo.** Wrapper
   fino sobre `AStarGrid2D`: region de `TileMapLayer.get_used_rect()`,
   `cell_size` do `TileSet`, `diagonal_mode = DIAGONAL_MODE_NEVER`,
   `default_compute_heuristic = HEURISTIC_MANHATTAN`. Lê a camada de dados
   customizados `"solido"` do mesmo `TileData` que a colisão física usa — mapa
   e navegação são o mesmo dado, nunca duas tabelas para desalinhar.

2. **`scripts/ia/astar_referencia.gd` (`AStarReferencia`) — implementação
   didática, explicitamente vetada para uso em runtime.** Fila de prioridade
   simples (busca linear pelo menor `f` — clareza em vez de desempenho, já que
   desempenho é papel do `AStarGrid2D`), nó com `g`, `h`, `f` e predecessor
   visíveis, conjuntos aberto e fechado como `Dictionary`. Serve a três
   propósitos, nenhum deles é "rodar o jogo":
   - gerar o pseudocódigo da monografia diretamente do código-fonte;
   - ser lida linha a linha na defesa;
   - servir de **oráculo de teste**: `tests/teste_astar.gd` roda as duas
     implementações sobre os mesmos 100 mapas aleatórios (gerados com semente
     fixa por índice, para qualquer falha ser reproduzível) e compara o custo
     do caminho. Divergência é bug — de qual lado, o teste não decide sozinho,
     mas como quem roda de verdade é `Navegacao`, é lá que se procura primeiro.

### Por que Manhattan + 4 direções + custo unitário é a heurística certa

Heurística admissível nunca superestima a distância real até o destino;
heurística consistente garante que a diferença de heurística entre duas
células vizinhas nunca excede o custo da aresta que as liga. Manhattan
(`|dx| + |dy|`) sobre uma grade sem diagonais e com custo 1 por passo cumpre
as duas propriedades ao mesmo tempo: a distância real mínima entre duas
células, movendo-se só em 4 direções, é exatamente `|dx| + |dy|` — a
heurística nunca subestima nem superestima o pior caso, e o A\* devolve
**caminho de custo mínimo garantidamente**, não só "na prática". É essa
garantia que justifica o algoritmo perante a banca, e é por isso que as duas
implementações usam a mesma heurística.

## Consequências

- Trocar o algoritmo de navegação do jogo (ex.: por desempenho, ou suporte a
  diagonais no futuro) é mexer só em `Navegacao`. `AStarReferencia` continua
  intocada — ela documenta o algoritmo clássico, não a decisão de produto.
- Se `AStarReferencia` algum dia for chamada por código de gameplay (mesmo que
  "só para depuração visual"), esta ADR foi violada. Registrado explicitamente
  em [ADR 0007, item 7](0007-marco1-cachorro-e-desafios.md) como o motivo
  pelo qual a depuração visual do A\* (tecla F3) desenha o caminho final, mas
  não os "nós expandidos" do algoritmo.
