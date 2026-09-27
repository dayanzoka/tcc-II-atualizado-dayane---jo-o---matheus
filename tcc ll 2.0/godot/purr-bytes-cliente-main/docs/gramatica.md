# Gramática do terminal

Implementação: `scripts/lexico/`. Decisões de fronteira entre as etapas em
[`docs/decisoes/0006-analisador-lexico-sintatico.md`](decisoes/0006-analisador-lexico-sintatico.md).

## Tabela de tokens

| Token | Padrão | Reconhecido por | Exemplo |
|---|---|---|---|
| `VERBO` | palavra reservada da gramática | pertence a `AnalisadorLexico.VERBOS_DA_GRAMATICA` = `{cifrar, decifrar, hash, verificar, dica, status}` | `cifrar` |
| `IDENTIFICADOR` | `[a-z][a-z0-9_]*` | letra seguida de letras/dígitos/underscore | `pacote`, `cyfrar`, `chave` |
| `NUMERO` | `[0-9]+` | um ou mais dígitos | `3` |
| `ATRIBUICAO` | `=` | caractere literal | `=` |
| `EOF` | fim da entrada | sempre o último token da lista | — |

`VERBOS_DA_GRAMATICA` é a lista **global** da linguagem, não
`FaseConfig.verbos_permitidos` (que restringe semanticamente o que cada fase
aceita — ver ADR 0006). `"chave"` não está na tabela de verbos: chega sempre
como `IDENTIFICADOR`, e é o parser, não o AFD, quem decide se abre um
`par_chave`.

## AFD (autômato finito determinístico)

Implementação: `AnalisadorLexico.tokenizar()`, caractere a caractere, sem
regex. Entrada já normalizada (trim + minúsculas) por quem chama.

```
                 espaço/tab
                ┌──────────┐
                │          │
                ▼          │
        ┌───────────────┐  │
   ─────▶│    INICIO     │──┘
        └───────────────┘
          │      │     │
     letra│  '='│digito│  outro caractere
          ▼      ▼      ▼                 ▼
   ┌────────────┐ ┌──────────┐ ┌────────┐  ERRO_LEXICO
   │IDENTIFICADOR│ │ATRIBUICAO│ │ NUMERO │  (nenhuma transição aceita)
   │  /VERBO*    │ │  (emite  │ │ (emite │
   │             │ │  token)  │ │ token) │
   └────────────┘ └──────────┘ └────────┘
    │        ▲
    │letra/  │
    │digito/ │
    │underscore
    └────────┘
    (auto-loop; sai em qualquer outro caractere)

   fim da entrada em qualquer estado de aceitação ──▶ emite EOF
```

`*` — o estado `IDENTIFICADOR` emite o token `VERBO` em vez de
`IDENTIFICADOR` **somente na saída**, se o lexema acumulado bater com a tabela
de verbos. É uma decisão de rótulo pós-aceitação, não um estado novo: o AFD
não sabe, enquanto consome caracteres, se vai virar verbo ou identificador.

Fica **fora** do alfabeto (dispara `ERRO_LEXICO`, com a posição exata do
caractere): acentuação, maiúsculas não normalizadas, pontuação além de `=`
(`!`, `,`, `?`, ...), qualquer símbolo que não seja letra minúscula, dígito,
`_` ou `=`.

## BNF

```
<comando>       ::= <verbo> <lista_arg> EOF
<verbo>         ::= "cifrar" | "decifrar" | "hash" | "verificar" | "dica" | "status"
<lista_arg>     ::= <argumento> <lista_arg> | ε
<argumento>     ::= <par_chave> | IDENTIFICADOR | NUMERO
<par_chave>     ::= "chave" ATRIBUICAO ( IDENTIFICADOR | NUMERO )
```

Implementação: `AnalisadorSintatico`, recursivo descendente, uma função por
produção (`_comando`, `_lista_arg`, `_argumento`, `_par_chave`). O eps de
`<lista_arg>` se resolve por lookahead: um `<argumento>` só começa com
`IDENTIFICADOR` ou `NUMERO`; qualquer outro token (inclusive `EOF`) termina a
lista sem consumir nada. `<par_chave>` também depende de lookahead: o
`IDENTIFICADOR` `"chave"` só abre a produção se o **próximo** token for
`ATRIBUICAO` — caso contrário é um argumento solto comum.

### TC-04

`cyfrar pacote chave=3` — o AFD forma `IDENTIFICADOR("cyfrar")` (não está na
tabela de verbos, mas é um lexema válido). `<comando>` exige `VERBO` na
primeira posição e encontra `IDENTIFICADOR`: **`ERRO_SINTATICO`**, não
`ERRO_LEXICO`. Justificativa completa: ADR 0006.

## Pipeline completo

```
texto bruto
   │  strip_edges().to_lower()
   ▼
normalizado ──▶ AnalisadorLexico.tokenizar() ──▶ Array[Token] ou ERRO_LEXICO
                                                        │
                                                        ▼
                                    AnalisadorSintatico.analisar()
                                                        │
                                          NoAst ou ERRO_SINTATICO
                                                        │
                                                        ▼
                               ResolvedorComando.resolver(FaseConfig, desafio)
                                                        │
                                     SUCESSO ou ERRO_SEMANTICO
```

`AnalisadorComando.analisar()` executa as duas primeiras etapas e devolve um
`ResultadoComando` pronto para telemetria
(`ResultadoComando.tokens_para_telemetria()` no formato
`{tipo, lexema, posicao}` que `Telemetria.registrar_tentativa()` espera). A
etapa semântica é sempre a última e é a única que conhece o `FaseConfig` e o
desafio corrente — ver ADR 0007 para as regras de negócio de
`ResolvedorComando`.
