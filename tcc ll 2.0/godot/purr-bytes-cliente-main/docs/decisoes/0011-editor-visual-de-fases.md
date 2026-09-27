# ADR 0011 — Editor visual de fases e fases como JSON

**Data:** 2026-09-16 · **Situação:** aceita · **Branch:** `reconstrucao-editor`

## Contexto

O pedido veio como "reconstruir o editor de fases, perdido no commit
`telemetria: id_fase universal...`". **A apuração do Git não confirmou a perda:**

- `5b443f5` não apagou nenhum arquivo (`git show --diff-filter=D` vazio); alterou dois.
- As 126 + 82 linhas removidas foram o `PainelTutorial` (a legenda de cores) e o
  `PainelTelemetria` de diagnóstico — que migrou para dentro do dashboard.
- `git log --all -S` por `CarregadorFaseJson`, `user://fases` e `FileDialog`: **zero
  ocorrências em toda a história**. `scripts/geracao/` nunca existiu.

Ou seja: o editor nunca esteve neste repositório. Isto é **construção**, não restauração —
registrado aqui porque a diferença importa para quem for auditar o histórico depois.

O que sobreviveu e foi reaproveitado inteiro: `FaseConfig` e subconfigs, `MapaConfig` com
`problemas()`, `Identificador`, `FaseBase` e a suíte.

## Decisões

### 1. O JSON é transporte de um `FaseConfig`, não um segundo modelo

`CarregadorFaseJson` lê e escreve; tudo vira `FaseConfig`/`MapaConfig`/`CachorroConfig`/
`PacoteConfig` e passa pelas **mesmas** funções `problemas()` que o jogo usa ao carregar.
Não há validação paralela para divergir. `terminais` mapeia direto em `PacoteConfig`, que
já tinha exatamente a forma (enunciado, opções, correta, explicação).

### 2. O mapa viaja como semente, não desenhado

O `.json` guarda `{largura, altura, seed}`; `GeradorDeMapa` reconstrói o labirinto. O
arquivo fica pequeno e legível, e a **mesma semente devolve o mesmo mapa** — a fase que o
professor testou é a fase que o aluno joga. Por isso a semente sorteada volta gravada ao
salvar: manter `seed: 0` faria cada abertura sortear outro labirinto.

### 3. "Sempre solucionável" é verificação, não promessa

O mapa só sai do gerador depois de passar por `MapaConfig.problemas()` — jogador, porta,
pacotes e cachorros alcançáveis, borda fechada, contagem batendo. Falhando, ele tenta a
próxima semente (até 12) e, se nem assim, devolve **erro** em vez de um labirinto quebrado.

O traçado é backtracker **iterativo** (a versão recursiva estouraria a pilha do GDScript
num mapa grande) seguido de **braiding**: 75% dos becos sem saída viram ciclo. Labirinto
perfeito encurrala quem foge e transforma a fuga em sorte; com ciclos, dar a volta no
perseguidor vira decisão — a diferença entre corredor linear e a sensação de Pac-Man.

### 4. Três modos de bloqueio, explícitos

`CachorroConfig.modo_de_bloqueio`: `CIFRA` (fases 1–3 do TCC), `COMANDO` (texto livre do
professor, comparação exata) ou `NENHUM` (só persegue). O modo é declarado, **não inferido**
de "o comando está vazio?": a diferença entre "não tem comando porque usa cifra" e "não tem
comando porque só persegue" é real, e inferir faria a validação de justiça cobrar cifra de
um cachorro que nunca foi feito para ser enganado.

O comando livre é testado **antes** do analisador léxico: o professor escreve o que quiser
sem precisar caber na gramática do TCC, que segue intacta para todo o resto. O comando
aceito entra na telemetria como tentativa, com tempo de resposta e resultado.

### 5. Fase de JSON não tem cena própria

`change_scene_to_file()` não aceita parâmetro, então `IniciadorDeFase` faz a troca à mão:
instancia `fase_base.tscn`, **atribui** a configuração e só então adiciona à árvore — a
ordem importa, porque `FaseBase._ready()` recusa a fase se a configuração estiver nula.
Isso evitou um autoload novo só para carregar um ponteiro entre telas; o caminho do arquivo
para o editor viaja numa `static var` (`EditorDeFaseEstado`) pelo mesmo motivo.

### 6. O editor lê a própria árvore de nós

Não há modelo em paralelo: `montar_dicionario()` percorre as linhas da tela. O que o
professor **vê** é o que é salvo, e não existe estado para dessincronizar. A opção correta
usa um `ButtonGroup` por terminal, então a escolha única sai de graça.

### 7. `id_fase` preservado em toda ida e volta

Editar, exportar e subir **nunca** trocam o `id_fase`. Ele é a chave que liga fase ↔
telemetria (ADR 0010 / `docs/contrato-telemetria.md`): trocá-lo desemparelharia o dado já
coletado da fase. Coberto por teste em cada caminho.

## Consequências

- Duas famílias de fase convivem: as três do TCC (cenas + `.tres`, proteção por cifra) e as
  de autoria (`.json`, bloqueio por comando). O motor é o mesmo; só o dado muda.
- `FaseConfig.problemas()` passou a exigir desafio de terminal **apenas** quando algum
  cachorro depende de cifra — fase de autoria é válida sem nenhum.
- `FaseConfig.numero` continua preso a 1..4 pelo `CHECK` do banco; fases de autoria usam
  `numero = 1` e se identificam pelo `id_fase`. Quando o `CHECK` cair, o campo pode virar
  ordem de verdade.
