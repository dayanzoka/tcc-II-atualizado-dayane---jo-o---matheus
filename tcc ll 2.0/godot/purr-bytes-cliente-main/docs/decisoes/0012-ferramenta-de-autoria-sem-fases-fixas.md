# ADR 0012 — Ferramenta de autoria: sem fases fixas, com menu de pause

**Data:** 2026-09-24 · **Situação:** aceita

## Contexto

Com o editor visual (ADR 0011) o professor passou a criar fases como JSON. As três
fases fixas do TCC (`cenas/fases/fase_0N.tscn` + `recursos/fases/fase_0N.tres`)
viraram um segundo caminho para a mesma coisa: mapa pintado por script
(`tools/gerar_fase_0N.gd`), encadeamento próprio (`_PROXIMA_CENA_POR_FASE`) e
testes de integração próprios. Dois caminhos para "uma fase" é exatamente o que o
RNF de manutenibilidade da monografia pede para evitar.

Além disso, a tecla `pausar` chamava `abandonar()` direto: um ESC por engano
descartava a tentativa e registrava `FASE_ABANDONADA` na telemetria — dado falso
de desistência.

## Decisões

### 1. O jogo não tem fase própria embutida

Saíram as cenas e recursos das fases 1 a 3, os geradores e o encadeamento. Para
jogar há três entradas, todas pelo mesmo `CarregadorFaseJson` → `FaseConfig` →
`IniciadorDeFase`:

- a fase de exemplo ("Senhas fortes"), semeada em `user://fases/` no primeiro boot
  e só se a pasta estiver vazia — o jogo nunca abre com a lista vazia;
- uma fase criada no editor;
- uma fase importada por arquivo.

César, Vigenère e SHA-256 continuam no jogo: viraram ferramentas que o professor
usa ao montar a fase, não "uma fase por cifra". Registrado como **evolução
consciente** em `docs/conformidade-monografia.md`, não como perda.

### 2. `fase_base.tscn` continua sendo a única cena de fase

A herança de cena e o `FaseConfig` continuam como no ADR 0004; o que mudou é que
o `FaseConfig` nasce em memoria a partir do JSON, em vez de ficar num `.tres`
atribuido a uma cena herdada.

### 3. Testes: fixture em memória, não fase fixa disfarçada

`tests/apoio_fase_de_teste.gd` monta um `FaseConfig` com a forma da antiga fase 1
(dois cachorros de César, três pacotes, um desafio de terminal) usando o mesmo
`GeradorDeMapa` das fases de autoria. Ele nunca é gravado em `user://fases` nem
aparece no menu. Os testes que validavam os `.tres` reais passaram a validar a fase
de exemplo, que agora é a fase "real" publicada.

### 4. ESC abre um menu de pause, não abandona

`PainelDePause` (Continuar / Reiniciar / Voltar ao menu) usa o mesmo mecanismo de
pausa do terminal e da caixa de puzzle (`get_tree().paused` + `process_mode =
ALWAYS` no painel). Só "Voltar ao menu" registra `FASE_ABANDONADA`: a
telemetria de abandono volta a significar decisão do jogador. Em `modo_treino` a
tecla não faz nada — um episódio de treino não pode travar esperando decisão de
interface.

## Consequências

- O critério do Marco 3 "as três fases jogáveis em sequência" deixa de se aplicar
  como escrito; a progressão agora é por fase escolhida.
- A constraint antiga do banco (`fase BETWEEN 1 AND 4`) precisa ser alinhada com o
  back-end: o cliente identifica a fase por `id_fase` (UUID).

## Correções posteriores (2026-09-25)

- **Reiniciar a fase** usava `reload_current_scene()`, que recarrega
  `fase_base.tscn` do disco. Fase de autoria não tem `.tscn` própria — a
  configuração vive em memória —, então a fase voltava sem `FaseConfig` e caía na
  tela de "configuração inválida". Agora reinicia pelo `IniciadorDeFase`, com a
  mesma configuração, o mesmo caminho do menu.
- **Comandos à vista:** `FaseConfig.mostrar_comandos` (JSON `"mostrar_comandos"`)
  põe na HUD uma legenda "cor do vigia → comando". É decisão do professor por fase:
  numa fase de apresentação o comando é o conteúdo ensinado; numa de avaliação,
  mostrar entregaria a resposta. A fase de exemplo liga. O exemplo gravado por
  versões anteriores é atualizado uma vez (`CarregadorFaseJson.atualizar_exemplo`),
  só se estiver intocado, preservando o `id_fase`.
- **Vigia que só persegue** era parado por qualquer cifra: a fase nunca consultava
  `CachorroConfig.apenas_persegue()` e ele caía na regra da cifra. Agora nada o
  para, como o editor promete.
