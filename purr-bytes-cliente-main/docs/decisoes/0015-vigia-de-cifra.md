# ADR 0015 — Vigia de cifra nas fases de autoria

**Data:** 2026-09-25 · **Situação:** aceita

## Contexto

Na revisão de conformidade com a monografia, apareceu uma lacuna criada pelo ADR 0012.
Quando as fases fixas saíram, o editor só oferecia vigias de **comando livre**
(`trocar senha`), comparados como texto antes do analisador. Com isso:

- nenhuma fase jogável tinha desafio de cifra, e `cifrar pacote chave=3` respondia "sem
  desafio ativo";
- o **TC-03** da monografia ("o analisador valida `cifrar` e o personagem passa ileso") e
  o RF "aplicar visualmente cifras e hashing como proteção" deixaram de ser demonstráveis;
- o painel de demonstração (`F4`) ficava sem exemplo.

O motor inteiro (AFD, parser, `ResolvedorComando`, César, Vigenère, SHA-256, painel)
continuava no código e testado. Só não havia caminho do editor até ele.

## Decisões

### 1. O tipo do vigia é escolhido no editor

Cada vigia tem um tipo, num `OptionButton`: *comando livre*, *cifra de César*, *cifra de
Vigenère*, *hash SHA-256* ou *só persegue*. O vigia de cifra pede **palavra** e **chave**
(SHA-256 não tem chave). Uma lista fechada, e não um campo de texto, porque o professor não
pode escrever um algoritmo que o jogo não conhece.

### 2. Vigia de cifra vira `DesafioConfig`

`CarregadorFaseJson` transforma cada vigia de cifra num desafio do terminal. Assim o
comando passa pelo mesmo pipeline do TCC: normalização → AFD → parser → validação
semântica, e a proteção sai da cifra real (`FabricaCifra`). Não há segundo caminho de
validação. O primeiro vigia de cifra dá o algoritmo da fase e o exemplo do painel `F4`.

A palavra e a chave são validadas na carga, com mensagem, porque viram tokens do terminal:
a palavra precisa casar com `IDENTIFICADOR` e não pode ser palavra reservada (um verbo no
lugar do argumento é erro sintático, e o jogador nunca conseguiria digitar o comando
certo); a chave de César vai de 1 a 25; a de Vigenère tem só letras. No SHA-256 a resposta
é o prefixo de 8 hex do digest real (`HashingContext`).

### 3. O terminal reconhece o desafio pelo comando

Com dois vigias de cifra, o jogador digita o comando do vigia que está na frente dele, não
o "próximo da fila". Se o comando corresponde a outro desafio da fase (mesmo verbo e mesma
palavra), esse desafio passa a ser o corrente antes da validação semântica.

### 4. A fase de exemplo ganha um vigia de César

`cifrar senha chave=3`: TC-03 e TC-04 ficam demonstráveis na fase que o jogo entrega
pronta. O exemplo gravado por versões anteriores é atualizado uma vez
(`versao_do_exemplo`), só se estiver intocado, preservando o `id_fase`.

## Consequências

- `tests/teste_casos_monografia.gd` roda TC-01 a TC-04 na fase de exemplo;
  `tests/teste_vigia_de_cifra.gd` cobre o JSON, a validação e o jogo.
- O comando livre continua existindo para frases de conduta que não cabem na gramática
  formal, e a diferença entre os dois caminhos está documentada em
  `docs/conformidade-monografia.md`.
