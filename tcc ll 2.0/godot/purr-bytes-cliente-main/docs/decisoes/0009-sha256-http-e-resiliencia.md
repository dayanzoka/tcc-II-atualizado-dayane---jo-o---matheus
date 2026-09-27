# ADR 0009 — SHA-256, transporte HTTP e resiliência de fila

**Marco:** 3 · **Data:** 2026-08-23 · **Situação:** aceita

## Contexto

O planejamento do Marco 3 (`CLAUDE.md`) pede para começar pelo servidor de
eco e pelo teste de resiliência, porque é ele que define a forma do cliente
HTTP — o SHA-256 vem depois. As rotas reais de
`Morc3go/prototipo` continuam sem implementação (confirmado antes de começar:
só existe `TelemetriaApplication.java`), então `TransporteHttp` precisa
nascer testável contra alguma coisa real sem depender do time do back-end.

## Decisões

### 1. `TransporteHttp` reaproveita um único `HTTPRequest`

`Telemetria.descarregar()` já serializa os envios — `await` no `enviar()`
anterior antes de chamar o próximo (seção 8: nenhum lote concorrente). Um
único `HTTPRequest` filho, criado em `_ready()` e reutilizado a cada
`enviar()`, é suficiente e mais simples que instanciar um nó novo por
requisição. `2xx` → sucesso; `4xx` → `falha_permanente` (lote malformado,
reenviar não ajudaria); `5xx` **e** qualquer falha de rede antes de uma
resposta HTTP → `falha_transitoria` — a mesma distinção que já regia o
transporte MOCK-de-teste em `tests/teste_telemetria.gd`, agora contra rede de
verdade.

### 2. `tools/servidor_eco.py`: eco puro, sem estado

~70 linhas de `http.server` da biblioteca padrão (sem dependência nova).
Aceita qualquer `POST` bem formado nas quatro rotas, responde `202` (o mesmo
código da API real — "aceito para processar", não "gravado") e grava cada
corpo recebido como uma linha JSON num arquivo de log. **Não simula 4xx nem
5xx por design**: essa distinção já está coberta por unidade (transporte
falso em `tests/teste_telemetria.gd`); o que só um servidor real prova é a
pilha de rede do Godot em si — conectar, enviar, receber, e sobreviver a uma
porta que para de responder no meio de uma partida.

`tests/apoio_servidor_eco.gd` sobe/derruba o processo Python de verdade
(`OS.create_process`/`OS.kill`), não um mock — é isso que faz
`tests/teste_resiliencia_http.gd` testar uma queda de rede real, não uma
falha simulada em memória.

### 3. Resiliência: matar o processo, não fingir a falha

O critério de aceite ("eco derrubado no meio da partida") é literal:
`tests/teste_resiliencia_http.gd` mata o processo do servidor, manda mais
eventos (a fila cresce, `itens_descartados` continua zero), religa o mesmo
processo na mesma porta **sem limpar o log** (precisa do histórico de antes
e depois da queda no mesmo lugar para provar "zero perdido, zero
duplicado"), drena, e conta `id_evento` únicos recebidos contra o total
esperado. A sonda de prontidão (`aguardar_pronto`) manda sua própria
requisição real para checar que o servidor subiu — e ela própria fica
registrada no log do eco, então o teste filtra pelo cabeçalho
`Authorization` (a sonda não manda nenhum) para não contar a si mesma como
dado da partida.

### 4. `Cifra` não serve para hash — `Sha256` é um utilitário à parte

`scripts/cripto/sha256.gd` não estende `Cifra`: hash não tem chave, não
cifra, não decifra. `HashingContext.update()` recusa buffer vazio (retorna
`FAILED` e loga erro) — `digest_hex()` pula a chamada quando o texto é
vazio, porque string vazia é um vetor **válido** (é literalmente um dos dois
vetores oficiais exigidos pelo critério de aceite) e não devia gerar log de
erro no caminho feliz.

### 5. `hash` calcula, `verificar` resolve — mesmo resolvedor genérico

`ResolvedorComando` ganha dois casos novos no mesmo `match` que já tinha
`cifrar`/`decifrar`/`dica`/`status` desde o Marco 1 — nenhuma mudança de
forma, só mais braços:

- **`hash <palavra>`** não depende de desafio (como `status`): é a
  ferramenta que o jogador usa para calcular um digest de verdade a qualquer
  momento, com o mesmo `Sha256.digest_hex()` que roda no jogo — não um valor
  fabricado.
- **`verificar <palavra> <prefixo_hash>`** resolve o desafio: sucesso quando
  o prefixo digitado bate com `DesafioConfig.resposta_esperada`, **mesmo
  padrão de comparação fixa** que `chave_esperada` já usava para César e
  Vigenère. `verificar` também ativa `duracao_protecao_s` — reinterpretado
  aqui como "integridade confirmada, pacote liberado para entrega" em vez de
  "texto ilegível para o cachorro". A mecânica de captura em
  `fase_base.gd` não muda uma linha; só o *significado* pedagógico da
  proteção muda entre fases, que é o próprio ponto do requisito de "baixo
  esforço de codificação através de matrizes de dados" (seção 1).

`tools/gerar_fase_03.gd` calcula `resposta_esperada` chamando
`Sha256.digest_hex()` de verdade sobre o `texto_claro` do desafio — nunca
transcrito à mão. Isso importa: um vetor de teste transcrito errado
(`tests/teste_sha256.gd`, um dígito a menos no digest de `""`) já escapou
uma vez nesta sessão de trabalho antes do teste pegar; gerar por código
fecha essa classe de erro na origem, não só na verificação.

### 6. Restrição de autoria: o prefixo do digest tem que começar com letra hex

`AnalisadorLexico` tokeniza `NUMERO` como dígitos contíguos e
`IDENTIFICADOR` como letra seguida de letra/dígito/`_`. Um prefixo de hash
que **começa com dígito e contém uma letra mais adiante** — por exemplo
`5d41402a` — quebra em dois tokens (`NUMERO("5")` + `IDENTIFICADOR("d41402a")`)
em vez de um só, porque `NUMERO` não continua em letra. Um prefixo que
**começa com letra** (`c00fe504`) tokeniza inteiro como um único
`IDENTIFICADOR`, porque essa produção aceita dígito depois da letra inicial.

Isso **não é um problema de gramática** — é a mesma tabela de tokens do
Marco 1, intocada. É uma restrição de **autoria de dado**:
`tools/gerar_fase_03.gd` recusa gerar a fase (`quit(1)`) se o prefixo
escolhido para algum desafio começar com dígito, forçando quem edita o
roteiro a escolher outro `texto_claro` até o digest natural começar com
`a`-`f`. Documentado aqui em vez de tocar `scripts/lexico/` — o mesmo
princípio usado no Marco 2 (tocar no parser sinalizaria generalização
falha) aplicado por analogia ao Marco 3: o parser continua o mesmo
desde o Marco 1, e este parágrafo é a prova de que isso foi verificado, não
presumido.

### 7. Painel de demonstração: avalanche para SHA-256, mesma tecla e mesmo evento

`FaseBase._alternar_painel_de_demonstracao()` passa a decidir por
`configuracao.algoritmo`: César/Vigenère abrem o alinhamento letra-a-letra do
Marco 2 (`PainelCifra.abrir`); SHA-256 abre
`PainelCifra.abrir_avalanche()`, que mostra dois digests completos lado a
lado com os dígitos hexadecimais divergentes destacados — `texto_b` é
`texto_exemplo_demonstracao` com **um caractere a mais**, gerado
automaticamente (sem precisar de um segundo campo no `FaseConfig`), porque
"alterar um caractere muda o digest inteiro" já é literalmente a frase do
critério de aceite. Mesma tecla (F4), mesmo evento (`CIFRA_DEMONSTRADA`,
reaproveitado — não existe um `HASH_DEMONSTRADO` separado no catálogo).

## Consequências

- `tools/roteiro_de_demonstracao.gd` (usado por
  `tools/sessao_de_demonstracao.gd` para gerar os exemplos de
  `docs/contrato-telemetria.md`) foi reescrito para montar `fase_01.tscn` de
  verdade e acionar o pipeline pelos sinais reais, em vez de chamar
  `Telemetria.registrar_evento()` com payloads escritos à mão. A versão
  anterior (Marco 0) tinha ficado desatualizada em pelo menos dois pontos —
  a classificação de TC-04 como `ERRO_LEXICO` (corrigida pelo ADR 0006 no
  Marco 1, nunca propagada ao roteiro) e o payload de `ERRO_LEXICO`
  (`{"lexema", "posicao"}`, que nunca existiu de verdade). Gerar por execução
  em vez de transcrever é o que a seção do documento já pedia
  ("Reexecute-o sempre que mudar a serialização") — só não tinha sido
  seguido à risca até agora.
- `docs/contrato-telemetria.md` está com exemplos regenerados desta execução
  (Marco 3). Reexecutar `tools/sessao_de_demonstracao.gd` depois de qualquer
  mudança no analisador, resolvedor ou catálogo de eventos é o que mantém
  isso verdade.
