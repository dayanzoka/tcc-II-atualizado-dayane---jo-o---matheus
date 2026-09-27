# ADR 0008 — Vigenère no resolvedor comum e painel de demonstração

**Marco:** 2 · **Data:** 2026-08-23 · **Situação:** aceita

## Contexto

O planejamento do Marco 2 (`CLAUDE.md`) é explícito: se a implementação da
Vigenère precisasse tocar no parser, isso significaria que a generalização do
Marco 1 falhou. Vigenère
usa a mesma forma de comando que César (`cifrar pacote chave=<valor>`), então
o teste real da arquitetura do Marco 1 é literal: implementar o algoritmo
inteiro tocando **zero linhas** em `scripts/lexico/`.

Duas coisas não tinham resposta pronta no Marco 1, porque só apareceram com
Vigenère: o que "faixa" (`FaseConfig.faixa_chave_minima/maxima`) significa
quando a chave não é um número; e como implementar o painel de demonstração
comparativa (seção 7) sem criar um jeito grátis de descobrir a chave do
desafio ativo.

## Decisões

### 1. `AnalisadorSintatico` não foi tocado

Confirmado: `scripts/lexico/analisador_sintatico.gd` e
`scripts/lexico/analisador_lexico.gd` não mudaram uma linha entre o Marco 1
e o Marco 2. A gramática já aceitava `IDENTIFICADOR` como valor de
`par_chave` (`<par_chave> ::= "chave" ATRIBUICAO (IDENTIFICADOR | NUMERO)`) —
"gato" sempre foi um `IDENTIFICADOR` sintaticamente válido; só ninguém tinha
testado semanticamente contra ele até agora. `docs/decisoes/0006` previu
exatamente isso. Se este parágrafo precisasse ser reescrito porque algo
mudou no parser, esta ADR estaria documentando uma falha, não um sucesso.

### 2. `Cifra` ganha dois métodos polimórficos para a etapa semântica generalizar

`ResolvedorComando` não sabe, e não deveria saber, se está validando César ou
Vigenère. Duas perguntas que ele precisa fazer mudam de significado por
algoritmo, então viraram métodos virtuais em `Cifra`
(`scripts/cripto/cifra.gd`), implementados em `CifraCesar` e `CifraVigenere`:

- **`dentro_da_faixa(chave, minimo, maximo)`** — para César, `faixa` é o
  VALOR da chave (`1 <= chave <= 25`); para Vigenère, é o COMPRIMENTO da
  chave (`3 <= chave.length() <= 8`). O mesmo par de campos do `FaseConfig`
  (`faixa_chave_minima/maxima`) atende os dois sem crescer um campo novo por
  algoritmo — cada `Cifra` decide o que "dentro da faixa" quer dizer para si.
- **`simbolos_de_chave(texto_claro, chave)`** — usado só pelo painel de
  demonstração (decisão 3): que símbolo de chave aparece embaixo de cada
  letra. César repete a mesma chave em toda posição; Vigenère avança pela
  chave, pulando posições que não são letra.

`FabricaCifra.para_algoritmo()` (`scripts/cripto/fabrica_cifra.gd`) é o único
`match "CESAR"/"VIGENERE"` do projeto — extraído de dentro de
`ResolvedorComando` porque `FaseBase`/`PainelCifra` também precisam
resolver "qual `Cifra` esta fase usa" para o painel, e duplicar o dispatch
seria o tipo de coisa que diverge silenciosamente quando a Fase 4 (AES)
chegar.

### 3. Painel de demonstração mostra um exemplo fixo, nunca o desafio ativo

A seção 7 pede um "painel lateral" que mostra "letra a letra, o texto claro
alinhado à chave repetida e ao texto cifrado". Não diz se esse texto é o do
desafio corrente. Decidido que **não é**: `PainelCifra.abrir()` recebe
`FaseConfig.texto_exemplo_demonstracao`/`chave_exemplo_demonstracao` — um
exemplo pedagógico fixo por fase, independente de qual desafio o jogador está
resolvendo. Motivo: o jogo já tem um mecanismo de ajuda com custo — o verbo
`dica` — e ele "gasta" pontos porque uma dica sobre o desafio ativo tem
valor. Uma tecla que abre um painel mostrando a chave que resolve o desafio
corrente, de graça, tornaria `dica` decorativa e a métrica de "acertou de
primeira" (Eixo 1) sem sentido: o jogador só precisaria olhar o painel antes
de digitar. O painel ensina o MECANISMO da cifra; resolver o desafio continua
custando tentativa.

Ativado por tecla própria (`mostrar_demonstracao`, F4), do mesmo jeito que F3
é a depuração do A\* — não por um verbo novo no terminal, que exigiria mexer
em `AnalisadorLexico.VERBOS_DA_GRAMATICA` (a lista GLOBAL de verbos, não
`FaseConfig.verbos_permitidos`) para todas as fases de uma vez, uma mudança
de escopo maior que o necessário para uma tecla de demonstração.

`CIFRA_DEMONSTRADA` é emitido só ao ABRIR o painel (não ao fechar) —
consistente com o catálogo de eventos, que descreve o código como "quando
aberto".

## Consequências

- `tests/teste_vigenere.gd` cobre os vetores exigidos (chave mais curta que o
  texto, chave com caractere inválido) mais o vetor clássico
  ("attackatdawn"/"lemon" → "lxfopvefrnhr", conferido à mão contra a
  referência pública da cifra).
- `tests/teste_resolvedor_comando.gd` tem uma seção dedicada a Vigenère
  reaproveitando os MESMOS testes de forma (chave ausente, verbo não
  esperado, sucesso ativa proteção) que já existiam para César, provando que
  o resolvedor generalizou de verdade.
- Se a Fase 4 (AES) precisar de uma terceira noção de "faixa" que não seja
  valor nem comprimento, o lugar de decidir isso é uma nova subclasse de
  `Cifra`, não `ResolvedorComando`.
