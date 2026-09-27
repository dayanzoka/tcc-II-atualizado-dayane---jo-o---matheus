# ADR 0005 — Suíte de testes sem addon

**Marco:** 0 · **Data:** 2026-08-21 · **Situação:** aceita

## Contexto

O `CLAUDE.md` proíbe addon de terceiros no núcleo do jogo e abre exceção para um
framework de testes (GUT ou gdUnit4). Consultado, o orientando do projeto pediu
para **usar ao máximo o que a engine oferece**.

## Decisão

Suíte própria, dois arquivos, nenhuma dependência externa:

- `tests/caso_de_teste.gd` — `class_name CasoDeTeste extends Node`, com as
  verificações (`afirmar_igual`, `afirmar_contem`, `afirmar_tamanho`, …) e os
  ganchos `antes()`/`depois()`.
- `tests/runner.gd` — `extends SceneTree`, executado por
  `godot --headless --path . --script res://tests/runner.gd`.

O Godot já oferece cada peça necessária:

| Necessidade | Recurso nativo usado |
|---|---|
| Ponto de entrada sem janela | `MainLoop` scriptável (`extends SceneTree`) + `--headless` |
| Descoberta de testes | `DirAccess.get_files_at()` e `Object.get_method_list()` |
| Teste assíncrono | corrotina (`await`) — `await caso.call(nome)` espera método corrotina e retorna na hora em método comum |
| Resultado para CI | `quit(0)` / `quit(1)` |
| Isolamento | `user://testes/`, limpo a cada execução |

Os autoloads existem durante a suíte exatamente como no jogo, o que permite
testar `Telemetria` de verdade — e não uma cópia dele. Para não tocar na fila
nem no `.jsonl` reais, `Telemetria.reiniciar(transporte, caminho)` aponta o
autoload para arquivos temporários.

Filtro por arquivo: `--script res://tests/runner.gd -- telemetria`.

## Consequências

- Zero addon, zero passo de instalação: qualquer máquina com o binário do Godot
  roda a suíte.
- A suíte reproduz o ciclo de vida real (autoloads, árvore, quadros), então pega
  classes de bug que teste puramente unitário não pegaria — foi assim que
  apareceu o `device = 16` do `InputEventKey`, que deixaria todas as ações
  mapeadas e nenhuma tecla respondendo.
- Falta o que um framework maduro traria: paralelismo, *mocks* automáticos,
  relatório em JUnit XML. Se o Marco 1 (analisador léxico-sintático, com dezenas
  de casos) mostrar que isso pesa, reabrir a decisão e considerar gdUnit4 — a
  migração é reescrever os `afirmar_*`, não os testes.
