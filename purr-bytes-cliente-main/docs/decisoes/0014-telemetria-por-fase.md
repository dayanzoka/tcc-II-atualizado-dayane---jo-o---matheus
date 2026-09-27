# ADR 0014 — Telemetria por fase: visão geral, fases jogadas e detalhe por `id_fase`

**Data:** 2026-09-25 · **Situação:** aceita

## Contexto

O dashboard (Figura 7) mostrava um retrato só: acertos × erros e tempo médio de
resposta, agrupados por fase numa tabela. Três problemas:

1. **Não havia telemetria de uma fase.** O professor não conseguia abrir uma fase e
   ver como ela foi jogada: quantas partidas, quantas concluídas, em quanto tempo.
2. **A última partida podia não aparecer.** A fila descarrega a cada
   `intervalo_envio_s`; voltar ao menu e abrir a telemetria antes disso lia um
   arquivo sem a partida recém-terminada.
3. **No modo HTTP o painel ficava vazio.** O histórico só existia no JSONL do modo
   MOCK — justamente na coleta real, o professor não via nada localmente.

## Decisões

### 1. A identidade da fase continua sendo o `id_fase` (UUID)

Já existia (ADR 0011) e já viaja em todo evento e tentativa. Nada novo no contrato:
jogar de novo a mesma fase gera eventos com o mesmo `id_fase`, então a telemetria
dela **soma** na mesma linha. Renomear a fase no editor não quebra a ligação: o
painel mostra o título atual, lido de `user://fases` por `id_fase`.

### 2. Partida = `FASE_INICIADA` → `FASE_CONCLUIDA`/`FASE_ABANDONADA` da mesma sessão

`ResumoTelemetria` reconstrói as partidas a partir dos eventos já existentes —
nenhum código de evento novo (restrição 7 do `CLAUDE.md`). Por fase: partidas,
concluídas, abandonadas, taxa de conclusão (sobre as que terminaram), tempo médio de
conclusão (diferença entre os dois `ocorrido_em`, relógio do cliente), pontuação
média e melhor (payload de `FASE_CONCLUIDA`), capturas (`JOGADOR_CAPTURADO`), dicas
(`DICA_SOLICITADA`) e o histórico de partidas.

Médias gerais são **ponderadas por partida/resposta**, não média de médias: uma fase
jogada uma vez não pesa igual a uma jogada vinte.

### 3. Filtro por fases é um parâmetro da agregação, não uma segunda agregação

`de_registros(registros, filtro_id_fases)`: filtro vazio = todas. "Média das
selecionadas" e "exportar selecionadas" usam o mesmo cálculo da visão geral, só com
o filtro. O JSON exportado diz qual filtro gerou os números (`filtro_id_fases`).

### 4. Tela em três níveis, com nós nativos

- **Visão geral** (abre primeiro): médias de todas as fases, ou das selecionadas.
- **Fases jogadas**: `ItemList` em `SELECT_MULTI` (ctrl/shift); o `id_fase` vai
  como metadado da linha; duplo clique (`item_activated`) abre a fase.
- **Detalhe da fase**: números da fase e histórico de partidas.

Tabelas com `[table]` do `RichTextLabel`, que alinha colunas com a fonte do tema.

### 5. Exportações

| Botão | Arquivo | Conteúdo |
|---|---|---|
| exportar geral | `user://resumo_telemetria.json` | resumo (com o filtro ativo) |
| exportar selecionadas | `user://exportacoes/telemetria_selecao.json` | resumo só das selecionadas |
| exportar esta fase | `user://exportacoes/telemetria_fase_<id8>.json` | resumo da fase **e** os registros crus dela |

Os registros crus vão junto na exportação da fase para quem analisa poder recalcular,
em vez de só confiar na média da tela. São os mesmos registros que saem para o
servidor — sem dado pessoal (restrição 1).

### 6. Descarga antes de ler; histórico local no modo HTTP

O painel chama `Telemetria.descarregar()` antes de ler o registro. No modo HTTP,
`Telemetria` grava uma cópia do que o servidor **aceitou** (2xx) em
`historico_telemetria.jsonl`, ao lado do arquivo de fila, no mesmo formato do MOCK.
A cópia é feita depois do 2xx de propósito: uma falha ao gravar a cópia não devolve
o item à fila, porque reenviar duplicaria dado de pesquisa no servidor.

### 7. Testes não escrevem mais em `user://fases`

`CarregadorFaseJson.pasta_das_fases` é trocada pelo `tests/runner.gd` para
`user://testes/fases`. Antes, um teste interrompido no meio deixava "Fase de teste"
na lista de fases do jogador.
