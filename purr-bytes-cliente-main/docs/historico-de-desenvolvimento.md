# Relatório — evolução de gameplay (modo humano)

**Data:** 2026-08-25 · **Escopo:** redesenho do laço de jogo para o jogador humano,
preservando o caminho de um futuro agente de aprendizado por reforço.
**Decisões e justificativas completas:** [ADR 0010](docs/decisoes/0010-modo-humano-cores-pacotes-e-porta.md).

---

## Observação inicial: o pedido descrevia outro código

O pedido citava `main.gd`, `game_map.gd`, `ai_controller.gd`, `cat_sprites.png`, `Lexer`,
`Telemetria.log_event`, `rl_mode`, `MAP` 15×15, `PACKETS` e `SERVER_POS`. **Nada disso
existe** neste repositório nem em `prototipo-main` — é o protótipo anterior que o próprio
`CLAUDE.md` (seção 1) classifica como descartável. Este repositório é a arquitetura do
`CLAUDE.md`: `FaseBase` + `TileMapLayer` + `FaseConfig` + `Telemetria.registrar_evento`.

As seis partes do pedido foram traduzidas para o código que existe de fato. Onde a
tradução mudou a forma da solução, está anotado abaixo.

---

## O que foi feito

### 1. Cachorro travado — causa raiz encontrada e corrigida

Não era o `_process` nem a velocidade. `Navegacao.calcular_caminho` usava
`AStarGrid2D.get_point_path`, que devolve o ponto no **canto** da célula
(`célula * cell_size`), enquanto `TileMapLayer.map_to_local` devolve o **centro**
(`célula * tile_size + tile_size/2`). Meia célula de diferença em cada eixo colocava
**todo waypoint sobre o canto de uma parede**: o corpo do cachorro (10×10 num tile de 16)
colidia, `move_and_slide` deslizava, e ele nunca alcançava a `tolerancia_de_chegada` de
4 px. Resultado: parado no primeiro waypoint, para sempre.

Corrigido com `get_id_path` + `map_to_local`, célula a célula
([navegacao.gd](scripts/ia/navegacao.gd)). Regressão travada em
`tests/teste_astar.gd::teste_waypoints_caem_no_centro_da_celula`.

Bug secundário no mesmo caminho: `Cachorro._physics_process` retornava sem chamar
`move_and_slide()` no quadro em que avançava o índice — um soluço a cada 16 px.

Também entrou **patrulha**: sem linha de visão e sem Diretor, o cachorro percorre em ciclo
as âncoras do `CachorroConfig` em vez de perseguir a posição real do jogador.

### 2. Labirinto 25×19

Era 15×9 (não 15×15) e consistia em dois corredores espelhados — daí a repetição. O novo
saiu de um backtracker recursivo de semente fixa, com câmaras carvadas e **16 aberturas
extras** que criam ciclos: existe mais de um caminho entre dois pontos, então fugir é
decisão e não corredor único. Conectividade verificada por inundação antes de o ASCII
entrar no repositório; o artefato versionado continua sendo o ASCII legível em
`tools/gerar_fase_01.gd`.

**Câmera:** 400×304 px numa viewport de 640×360 — o mapa inteiro cabe, então a câmera fica
fixa no centro. Se um mapa futuro passar do tamanho da tela, ela volta a seguir o jogador,
presa aos limites de `get_used_rect()`.

### 3. Cachorros coloridos, cada cor = uma criptografia

`FaseConfig.cachorros: Array[CachorroConfig]` (posição, âncoras, algoritmo, velocidade).
O cachorro da cena pai vira o nº 1; os demais são instâncias da mesma cena. As cores saem
de `LegendaCores`, **fonte única** compartilhada por cachorro, HUD, botões do puzzle e
tutorial — mudar uma cor lá muda tudo de uma vez.

`Jogador.algoritmo_protegido` guarda qual cifra está ativa, e `_protegido_contra()` compara
com o `algoritmo_exigido` de quem encostou: **cifrar em César não engana quem lê Vigenère**,
e a tela de captura diz exatamente isso.

**Desvio deliberado do pedido:** o pedido pedia 2–3 cores já na fase 1, com `sha`/`aes`/`rsa`.
Duas mudanças:

- **AES/RSA viraram César/Vigenère/SHA-256.** `aes` e `rsa` não são verbos do AFD e não
  têm implementação; usar os três algoritmos que o jogo realmente ensina mantém a mecânica
  ligada ao conteúdo do TCC.
- **A fase 1 tem dois cachorros, ambos verdes.** Um cachorro azul na fase 1 seria captura
  inevitável, porque o jogador ainda não tem como produzir Vigenère ali. A progressão é
  fase 1 = verde · fase 2 = verde + azul · fase 3 = as três. A fase 1 ensina a **ler** a
  cor; a escolha entre cores começa na fase 2, quando ela é justa.

Para que "justo" não dependa de disciplina, `FaseConfig.problemas()` **recusa a fase** se
algum cachorro exigir uma cifra que nenhum desafio daquela fase produz.

Duas consequências de projeto: `DesafioConfig.algoritmo` (vazio = herda o da fase), o que
permitiu desafios de revisão nas fases 2 e 3; e os **desafios agora ciclam**, para o jogador
sempre conseguir reaplicar a cifra que a cor exige — resolver de novo não pontua.

### 4. Caixa de puzzle no pacote

Três pacotes por fase. Encostar abre um painel com um botão por opção, na cor do algoritmo;
acertar coleta, errar custa pontos e deixa tentar de novo; `ESC` fecha sem responder. A
caixa pausa a árvore e roda com `process_mode = ALWAYS` — a pausa é o que impede uma captura
enquanto o jogador lê.

Botão em vez de campo de texto porque o terminal **já** mede digitação; o pacote mede
**escolha**, e erro de digitação aí viraria ruído no dado.

**Telemetria:** vai como `tentativa_comando` com `desafio` prefixado de `pacote-`,
`SUCESSO`/`ERRO_SEMANTICO` e `codigo_erro = "opcao_incorreta"`. Nenhum código de evento novo
foi inventado — o catálogo é fechado pelo banco (restrição 7 da seção 4 do `CLAUDE.md`), e um
código inventado viraria `INSERT` rejeitado, ou seja, dado de pesquisa perdido. Exemplo real
documentado em [docs/contrato-telemetria.md](docs/contrato-telemetria.md).

### 5. Porta

`Marcadores/PontoDeSaida` ganhou o script `porta.gd`: cadeado vermelho enquanto faltar
pacote, vão verde depois. Chegar trancado escreve no terminal quantos faltam, sem punição.
Aberta, ela leva direto à fase seguinte — o encadeamento já existia em
`FaseBase._PROXIMA_CENA_POR_FASE`, e **é ali que a fase 4 entra, com uma linha**.

### 6. Tutorial de cores no menu

Botão **tutorial de cores** e painel no estilo do painel de telemetria, montado a partir de
`LegendaCores.entradas()` — a "cola" não pode discordar do jogo, então ela lê o mesmo dado.
Traz a legenda cor → cifra, uma frase explicando cada algoritmo (hash × cifra simétrica ×
chave-palavra) e as teclas.

---

## O modo RL continua intacto

Não existe `rl_mode` neste repositório. A chave foi criada como
`ConfigJogo.modo_treino` (`config.cfg`, seção `[jogo]`, padrão `false`), e **só** as duas
mecânicas que pressupõem um humano ficam atrás dela:

| | `modo_treino = false` | `modo_treino = true` |
|---|---|---|
| Pacote | abre a caixa de puzzle | coletado ao encostar |
| Proteção | só a cifra da cor do cachorro | qualquer cifra ativa |

Labirinto, A\*, patrulha, Diretor, terminal, porta, vidas, pontuação e telemetria são
idênticos nos dois modos. Coberto por
`tests/teste_modo_humano.gd::teste_modo_treino_coleta_direto_e_aceita_qualquer_cifra`.

---

## Testes

Arquivo novo `tests/teste_modo_humano.gd` (10 testes, 50 verificações): cores vindas da
legenda, patrulha sem perseguição, cifra certa × errada, captura com cifra errada e o que
ela registra, caixa de puzzle (erro → acerto, telemetria, pausa), cancelamento, porta
trancada/aberta, modo de treino e a recusa de cachorro impossível.

Suíte completa, exceto os dois arquivos de HTTP:

```
analisador 23 · astar 4 · catalogos 4 · cenas 6 · cesar 7 · config_jogo 7
demonstracao 7 · diretor 7 · encadeamento 2 · entrada 5 · fase 23
identificador 4 · menu 1 · modo_humano 10 · relogio 4 · resolvedor 21
sha256 5 · telemetria 14 · vigenere 7
```

**161 testes, 941 verificações, 0 falhas.**

`teste_transporte_http.gd` e `teste_resiliencia_http.gd` **não foram executados**: eles
sobem `tools/servidor_eco.py` como processo real e não há `python` instalado nesta máquina.
Nada nesta entrega toca o transporte HTTP, mas isso precisa rodar numa máquina com Python
antes de fechar a validação.

---

## O que precisa ser validado à mão (não dá para fazer por código)

1. **Jogar a fase 1 inteira no editor.** Ritmo, distância entre pacotes, agressividade das
   patrulhas e legibilidade das cores só se avaliam em tela. O traçado foi conferido por
   conectividade e integração, nunca visto.
2. **Clicar nos botões da caixa de puzzle com o jogo pausado.** Os testes chamam
   `escolher()` diretamente; o caminho de mouse/teclado com `process_mode = ALWAYS` é
   sólido por construção, mas merece um clique de verdade.
3. **Travessia menu → fase 1 → fase 2 → fase 3 → menu**, agora com a porta no meio. Continua
   sem teste automatizado pelo mesmo motivo do Marco 3 (`change_scene_to_file` dentro do
   processo compartilhado da suíte).
4. **Contraste das cores** no projetor/monitor da escola — verde, azul e roxo foram
   escolhidos com luminosidade parecida, mas isso se confirma olhando.

## O que ficou de fora, e por quê

- **Fases 2 e 3 continuam com o labirinto antigo** (19×13, idêntico entre as duas).
  Ganharam cachorros coloridos, pacotes e porta, mas o remodelamento do traçado não foi
  pedido.
- **Uma crença do Diretor por cachorro.** Nas fases 2 e 3 todos perseguem a mesma região
  suspeita — eles se espalham na varredura, mas andam em matilha. Separar as crenças mexeria
  no ADR 0002 e não estava no escopo.
- **Tela de "fase concluída"** entre fases: as três fases existem e encadeiam direto, então
  a tela de "fase 2 em breve" prevista no pedido não tem quando aparecer.

---
---

# Refinamento — tutorial e banco de perguntas

**Data:** 2026-08-25 · **Escopo:** conteúdo educativo e clareza conceitual. Nenhuma mudança
estrutural: `FaseConfig`/`PacoteConfig` continuam sendo o dado, `fase_base.gd` a lógica,
`LegendaCores` a fonte única.

## 1. A ambiguidade "chave × ferramenta"

O jogo pede **duas decisões diferentes** e o tutorial as embaralhava numa frase só. A correção
foi separá-las em dois blocos, com títulos explícitos:

| | antes | agora |
|---|---|---|
| Texto da legenda | "cifra de deslocamento: cada letra anda um número fixo de casas. **a chave é esse número.** comando: cifrar (pacote) chave=(numero)" — cor e chave na mesma frase, logo abaixo da tabela de cores | `LegendaCores._EXPLICACOES` descreve **só o mecanismo**; a palavra "chave" foi removida dali |
| Onde a chave aparece | espalhada, como sinônimo vago de "resposta" | dicionário novo `LegendaCores._CHAVES` + `chave(algoritmo)`, consumido por um bloco separado do tutorial |
| Tutorial | uma lista única | **bloco 1: "a COR do cachorro escolhe a FERRAMENTA"** (+ "cada cor pede sempre a mesma ferramenta, em qualquer fase: um cachorro verde na fase 3 continua pedindo César") · **bloco 2: "a CHAVE é o segredo que faz a ferramenta funcionar"** (César pede um número, Vigenère uma palavra, SHA-256 **nenhuma**) |

A frase que fecha a ambiguidade está no bloco 2: *"a cor não é a chave."*

## 2. Perguntas: antes × agora

`PacoteConfig` ganhou o campo `tipo` (`APLICACAO` | `CONCEITO` | `DISCERNIMENTO`). Em
`APLICACAO` as opções são códigos de algoritmo (botão colorido, nome vindo da legenda); nos
outros dois são frases exibidas como estão. Cada fase passou a ter **um de cada arquétipo**.

### Fase 1 — antes: três perguntas, três respostas `CESAR`

| antes | problema | agora |
|---|---|---|
| "este pacote precisa atravessar o corredor onde ronda um cachorro VERDE. qual cifra o protege ali?" → `CESAR` | ok — virou o arquétipo Aplicação | **Aplicação:** "um cachorro VERDE ronda o corredor por onde este pacote precisa passar. qual ferramenta protege o conteúdo dele?" → `CESAR` |
| "na cifra de **César**, o que exatamente é a chave que você digita?" → opções `[CESAR, VIGENERE, SHA256]`, resposta `CESAR` | o enunciado cita a resposta **e** as opções não respondem à pergunta feita | **Conceito:** "no comando `cifrar pacote chave=3`, o que é o 3?" → opções conceituais: *"quantas casas cada letra anda no alfabeto"* (correta) · "a cor do cachorro que está perseguindo" · "quantos pacotes ainda faltam coletar" |
| "um pacote em texto claro foi interceptado. que ferramenta teria impedido a leitura?" → `CESAR` | terceira resposta `CESAR` seguida: ensina a repetir, não a pensar | **Discernimento:** "deslocar todas as letras o mesmo tanto é fácil de quebrar. por quê?" → *"só existem 25 deslocamentos: dá para testar todos"* |

A opção distratora *"a cor do cachorro"* na pergunta de conceito é proposital: é exatamente o
erro que o tutorial antigo induzia.

### Fase 2 — antes: duas de três respostas iguais, uma com a resposta no enunciado

| antes | problema | agora |
|---|---|---|
| "um cachorro AZUL bloqueia a saída. qual cifra o engana?" → `VIGENERE` | ok | **Aplicação:** "o cachorro que patrulha esta passagem é VERDE. qual ferramenta protege o pacote dele?" → `CESAR` — numa fase de Vigenère. É a pergunta que ensina que **a cor manda, não a fase** |
| "qual das duas resiste à análise de frequência, por trocar o deslocamento a cada letra?" → `VIGENERE` | o enunciado descreve o mecanismo do Vigenère e pede o nome dele: resposta embutida | **Conceito:** "nesta fase a chave é uma palavra em vez de um número. o que isso muda no embaralhamento?" → *"cada letra anda um tanto diferente, seguindo a palavra"* |
| "e contra o cachorro VERDE aqui embaixo, qual delas serve?" → `CESAR` | ok, mas repetia o formato da primeira | **Discernimento:** "contar quais letras mais se repetem ajuda a quebrar um deslocamento fixo. por que isso para de funcionar aqui?" → *"a mesma letra vira letras diferentes em cada posição"* |

### Fase 3 — antes: duas respostas `SHA256`, uma delas com o mecanismo no enunciado

| antes | problema | agora |
|---|---|---|
| "o pacote chegou com um resumo anexado e você precisa saber se foi adulterado. que ferramenta responde isso?" → `SHA256` | redundante com a de discernimento | **Aplicação:** "um cachorro AZUL apareceu no corredor de baixo. qual das três ferramentas protege o pacote dele?" → `VIGENERE` |
| "qual destas NÃO dá para desfazer, nem com a chave certa?" → `SHA256` | ok — virou o arquétipo Discernimento, reescrito | **Discernimento:** "qual destas NÃO serve para esconder um conteúdo que precisa ser lido de volta depois?" → `SHA256` |
| "um cachorro AZUL apareceu. qual das três protege?" → `VIGENERE` | ok — virou o arquétipo Aplicação | **Conceito:** "você mudou UMA letra do pacote e o resumo saiu completamente diferente. o que isso mostra?" → *"qualquer alteração no conteúdo aparece na hora"* |

## 3. Aleatoriedade

Duas camadas, ambas **dentro da mesma fase** — o participante sempre recebe as mesmas
perguntas, então o instrumento é idêntico para todos e não se introduz confundidor
metodológico (ADR 0002: regras fixas e iguais para todos):

- **Ordem das opções** sorteada a cada abertura da caixa (`CaixaPuzzle._embaralhar`). Sem isso
  a resposta certa fica sempre no mesmo botão e o jogador aprende a posição, não o conteúdo.
- **Perguntas embaralhadas entre si** pelas posições do mapa (`FaseBase._configurar_pacotes`):
  as células continuam sendo as declaradas — escolhidas para ficarem espalhadas —, mas qual
  pergunta cai em qual posição muda a cada partida. Ninguém decora "no canto nordeste a
  resposta é César".

Nenhuma semente fixa foi necessária: os testes verificam **valores** (a opção escolhida, o
conjunto de opções), nunca posições, então o sorteio não os torna instáveis. Qual pergunta o
jogador respondeu continua na telemetria pelo identificador do pacote (`pacote-f1-conceito`),
não pela posição.

## 4. Duas regras viraram validação, não disciplina

`PacoteConfig.problemas()` agora **reprova a fase** se:

- um enunciado de `APLICACAO` citar o nome do algoritmo que é a própria resposta (era o bug da
  fase 1, que a revisão manual já tinha deixado passar uma vez);
- as opções não combinarem com o tipo da pergunta (nome de algoritmo em pergunta conceitual,
  ou frase em pergunta de aplicação).

`tests/teste_modo_humano.gd` carrega os três `.tres` reais e exige, além disso, que cada fase
tenha **ao menos duas respostas corretas distintas** e **ao menos dois arquétipos** — o
"três vezes CESAR" da fase 1 não pode voltar sem quebrar a suíte.

## 5. Testes

`teste_modo_humano.gd` foi de 10 para **13 testes / 109 verificações**, com os três novos:
enunciado que não entrega a resposta, embaralhamento das opções (24 aberturas, sem perder nem
inventar opção) e troca de posição das perguntas entre partidas.

Suíte após a mudança: `fase` 23 · `cenas` 6 · `menu` 1 · `resolvedor` 21 · `diretor` 7 ·
`astar` 4 · `telemetria` 14 · `catalogos` 4 · `modo_humano` 13 — **todos verdes**. Os dois
arquivos de HTTP continuam sem rodar (dependem de `python`, ausente nesta máquina) e não são
tocados por esta mudança.

## 6. Como testar à mão

1. **Menu → tutorial de cores.** Devem aparecer dois blocos numerados. O bloco 1 associa cor →
   ferramenta e diz que a regra vale em qualquer fase; o bloco 2 diz qual segredo cada
   ferramenta pede e afirma que "a cor não é a chave". A palavra "chave" não deve aparecer no
   bloco 1.
2. **Jogar a fase 1 duas vezes.** As três perguntas devem aparecer em **posições diferentes**
   entre as partidas, e as respostas certas são diferentes entre si (uma é `CESAR`, as outras
   são frases).
3. **Abrir a mesma caixa de puzzle algumas vezes** (erre de propósito, ou saia com `ESC` e
   volte): a ordem dos botões deve mudar.
4. **Ler os enunciados** procurando o nome da ferramenta que é a resposta — não deve haver
   nenhum. Se houver, o jogo nem carrega a fase: a validação reprova.
5. **Fases 2 e 3:** confirmar que a pergunta de aplicação da fase 2 responde `César` (numa
   fase de Vigenère) e a da fase 3 responde `Vigenère` (numa fase de SHA-256) — é assim que se
   vê que a fase nova não cancela a regra antiga.

---
---

# Manutenção — mapas validados, cachorros, pausa e cifra explicada

**Data:** 2026-08-27 · **Escopo:** correção e sistematização. A arquitetura em camadas
(autoloads, `FaseConfig`/`DesafioConfig`/`PacoteConfig`, `LegendaCores`, `cripto/`,
`navegacao.gd`) ficou intacta; entrou um recurso novo, `MapaConfig`, no mesmo padrão dos
demais.

## 1. Por que as fases 2 e 3 travavam — não era o desenho do mapa

O diagnóstico do pedido era que os mapas tinham buracos. **Não tinham.** Conferi célula a
célula: os grids das fases 2 e 3 estavam íntegros, conectados, e pacotes, cachorros e porta
todos sobre piso.

O que travava era o **Diretor**. Ele publica o *centro* de uma região como alvo, e
`FaseBase._alvo_de_varredura` varre pontos a ±16 px (±1 célula) desse centro para o cachorro
não ficar parado em cima de um ponto só. Nada garantia que esses pontos caíssem em piso.

No mapa antigo da fase 2, o centro da região noroeste era a célula (4,3); o offset `(0,16)`
apontava para (4,4), que é parede. `Navegacao.calcular_caminho` devolve caminho vazio quando
o destino é sólido → o cachorro parava. E o índice da varredura só avança quando ele *chega*
ao ponto — que nunca aconteceria. **Travamento permanente**, e só nas fases com Diretor,
que é exatamente o sintoma relatado (a fase 1 não tem Diretor e não travava).

Correção em duas camadas:

- `Navegacao.ponto_andavel_mais_proximo()` — busca em largura pela célula livre mais próxima.
  Todo alvo de varredura e de patrulha passa por ela agora.
- Se mesmo assim o caminho voltar vazio (região separada, por exemplo), o índice da varredura
  avança em vez de insistir no mesmo ponto para sempre.

Regressão: `teste_modo_humano.gd::teste_alvo_de_varredura_nunca_cai_em_parede` percorre a
tabela de varredura inteira nas 4 regiões da fase 2 e falha se qualquer alvo cair em parede.

## 2. `MapaConfig`: o labirinto virou texto validado

Mesmo não sendo a causa do travamento, o diagnóstico do pedido estava certo sobre o risco: o
labirinto só existia pintado dentro do `.tscn`, e `Navegacao._e_solido` trata célula **não
pintada** como parede. Um tile esquecido no editor viraria parede invisível, sem uma linha de
erro. Agora:

- O mapa é um grid ASCII (`#` parede, `.` piso, `P` jogador, `S` porta, `o` pacote,
  `D` cachorro) dentro de um `MapaConfig`, guardado no `.tres` da fase.
- `FaseBase._ready` **repinta** o `TileMapLayer` a partir desse texto e posiciona jogador,
  porta, pacotes e cachorros pelos marcadores, na ordem de leitura. O texto é a fonte; o
  TileMap e o `AStarGrid2D` são derivados — não há tabela paralela para divergir.
- `MapaConfig.problemas()` recusa a fase, com mensagem clara, quando: o grid não é retangular,
  há caractere fora da legenda, a borda externa tem buraco, falta `P`/`S` (ou há mais de um),
  a contagem de `o`/`D` não bate com a lista do `FaseConfig`, ou **pacote, porta, cachorro ou
  âncora de patrulha é inalcançável** a partir do `P` (inundação em 4 direções, as mesmas do
  A\*). Cachorro sem vizinho andável também reprova.
- O validador roda nos dois lados: no gerador (antes de escrever o `.tres`) e no `_ready` da
  fase, via `FaseConfig.problemas()`.

Cobertura: `tests/teste_mapa_config.gd`, 10 testes — cada um é um bug que antes passava
silencioso — mais a verificação de que as três fases reais passam.

## 3. Mapas 2 e 3 redesenhados

Eram o **mesmo** labirinto serpenteado 19×13 nas duas fases, o que fazia a fase final parecer
repetição da anterior. Agora são dois traçados distintos de 21×15, com câmaras e ciclos,
gerados e conferidos pelo validador antes de entrar no arquivo. Os centros das 4 regiões do
Diretor foram garantidos em piso.

## 4. O terminal pausa o jogo

Digitar `cifrar pacote chave=3` com um cachorro colado nas costas mede velocidade de digitação
sob pânico, não aprendizado. Abrir o terminal agora pausa a árvore, como a caixa de puzzle.

Detalhe de implementação que o pedido não previa: com a árvore pausada, o `_unhandled_input`
da fase não roda. As teclas de **fechar** passaram para dentro do próprio terminal (que tem
`process_mode = ALWAYS`), senão abrir o terminal seria uma armadilha — jogo pausado e nenhuma
tecla capaz de sair.

Sobre o tempo: a contagem de `duracao_cifra_s` corre em `Jogador._physics_process`, que não
roda pausado, então **a pausa não consome tempo de cifra** — ler com calma não é punido.
Já `tempo_resposta_ms` continua no relógio de parede, ou seja, mede o tempo *pensando*, que
é a métrica do Eixo 1 e agora vem sem o ruído da fuga simultânea. Ambos com teste.

## 5. A cifra passou a se explicar

`scripts/cripto/` não foi tocado — a matemática já estava certa e testada. O que mudou é a
apresentação: ao acertar, o terminal imprime

```
--- o que aconteceu com o pacote ---
claro   : p  a  c  o  t  e
chave   : 3  3  3  3  3  3
cifrado : s  d  f  r  w  h
o cachorro agora ve 'sdfrwh', e nao 'pacote' -- e por isso que ele passa direto.
```

O alinhamento vem de `DemonstracaoCifra.montar()`, a **mesma** função que alimenta o painel de
demonstração — não há uma segunda forma de explicar a cifra no projeto. No SHA-256 o texto é
outro, porque a lição é outra: o resumo confere integridade, é de mão única, e não existe
desfazer.

Decisão deliberada: isso **não** emite `CIFRA_DEMONSTRADA`. Aquele evento mede o jogador
*escolher* ver a explicação (Eixo 2); emiti-lo a cada acerto transformaria o indicador num
contador de acertos.

## 6. As opções do puzzle perderam a cor

Os botões de resposta são neutros, inclusive quando a opção é o nome de um algoritmo. A cor
continua onde ela é mecânica — no cachorro, na HUD e no tutorial —, mas dentro da caixa ela
virava muleta: bastava parear a cor do botão com a do cachorro que acabou de passar para
acertar sem entender nada, e é justamente o entendimento que o puzzle mede. Com teste que
falha se algum botão tiver `font_color` sobrescrito.

O banco de perguntas e o embaralhamento das opções ficaram como estavam, a pedido.

## 7. Testes

**180 testes, 1047 verificações, 0 falhas** (era 161/941).

Arquivo novo `tests/teste_mapa_config.gd` (10 testes) e mais 6 em `teste_modo_humano.gd`
(19 no total): varredura nunca em parede, travessia do labirinto ponta a ponta sem waypoint em
parede, correção de ponto em parede, pausa do terminal, proteção que não corre pausada, e
ausência de cor nas opções.

`teste_transporte_http.gd` e `teste_resiliencia_http.gd` continuam **sem rodar**: sobem
`tools/servidor_eco.py` e não há `python` nesta máquina. Nada nesta entrega toca o transporte
HTTP.

## 8. Como testar à mão

1. **Validador recusando um mapa quebrado.** Em `tools/gerar_fase_01.gd`, troque um `.` por
   `#` isolando um `o` (ou apague um caractere de uma linha) e rode
   `godot --headless --path . --script res://tools/gerar_fase_01.gd`. Ele deve **falhar**
   dizendo qual pacote ficou inalcançável (ou qual linha ficou com tamanho diferente), sem
   gravar nada. Desfaça e rode de novo para ver passar.
2. **Fases 2 e 3.** Jogue as duas: os cachorros devem patrulhar e perseguir continuamente,
   sem nenhum parar de vez no meio do mapa. `F3` mostra o caminho de cada um, na cor dele.
3. **Pausa do terminal.** Com um cachorro perto, aperte `T`: tudo congela, inclusive ele.
   Digite com calma, aperte `ESC` e confirme que o jogo volta a andar. Confira também que o
   contador de cifra na HUD não anda enquanto o terminal está aberto.
4. **Cifra explicada.** Resolva `cifrar pacote chave=3` e leia o bloco "o que aconteceu com o
   pacote": as três linhas alinhadas e a frase do que o cachorro passa a ver.
5. **Puzzle sem cor.** Encoste num pacote: os botões devem estar todos na mesma cor neutra, e
   a ordem deve mudar se você reabrir a caixa.
6. **Criar uma fase nova**, seguindo o passo a passo do `README.md` — é o teste real de que o
   esquema ficou seguro de usar.

---
---

# Tutorial removido, telemetria global e Dashboard

**Data:** 2026-09-14 · **Escopo:** as quatro partes do pedido, executadas na ordem pedida.

## 0. Uma premissa do pedido que não se confirmou

O pedido parte de que "o projeto virou uma ferramenta de autoria: o professor cria fases
(JSON + editor), define cachorros com cor livre e comando de bloqueio em texto livre".
**Isso não existe neste repositório.** Ele está em `f0fa062`, igual ao `origin/main`: sem
editor de fases, sem `.json` de fase, sem comando em texto livre, e o `CachorroConfig` não
tinha campo `cor` (o pedido supõe que "provavelmente já existe").

Mais importante: a regra "cor = cifra" **não era legado morto** — era e continua sendo a
mecânica central (`FaseBase._protegido_contra`, `FaseConfig.problemas()`). Levantei isso
antes de começar; a resposta foi seguir o script, e foi o que fiz. O que a Parte 1 removeu
foi a camada que **ensinava** a regra, não a regra. A consequência está registrada abaixo e
em `docs/conformidade-monografia.md` — não foi enterrada.

## 1. O que saiu, o que ficou

| Removido | Por quê |
|---|---|
| Botão "tutorial de cores" e `PainelTutorial` (menu) | ensinava a associação cor → cifra |
| `_montar_tutorial`, `_ao_abrir_tutorial`, `_ao_fechar_tutorial` e os `@onready` órfãos | idem |
| Coloração do aviso de proteção na HUD | a cor deixou de ser código semântico |
| `LegendaCores._EXPLICACOES`, `_CHAVES`, `_NOMES_DAS_CORES`, `entradas()` | existiam só para o tutorial |
| Frases "o cachorro **verde** lê César" (captura, terminal, feedback dos pacotes) | afirmavam a regra removida |

| Preservado | Como |
|---|---|
| **Cor do cachorro** | virou dado próprio: `CachorroConfig.cor` (livre), com a cor do algoritmo só como default. `Cachorro.definir_cor()` substituiu a derivação. Coberto por teste. |
| **Aviso de proteção** | continua dizendo qual cifra está ativa e por quanto tempo — em branco. |
| **A mecânica** | cada cachorro ainda exige um algoritmo; cifra errada não protege. |
| `LegendaCores` | reduzido a `nome()`, `cor()` e `conhece()` — os três em uso real (rótulos, default de cor, validações). Não foi apagado. |

**Pendência honesta:** sem o tutorial, o jogador só descobre qual cifra engana qual
interceptador ao **ser pego** (a tela de captura nomeia o algoritmo). E três perguntas de
pacote ainda dizem "um cachorro VERDE ronda...", pressupondo a legenda que saiu. Não
reescrevi o banco de perguntas porque não foi pedido e porque na tarefa anterior a
orientação foi deixá-lo como está. Está listado em `docs/conformidade-monografia.md` como
item a resolver antes da coleta.

## 2. Telemetria global

O diagnóstico do pedido estava **certo**: `telemetria.gd` descartava tentativa com fase fora
de 1..4 e `sessao.gd` fazia `clampi(numero, 1, 4)`.

- `FaseConfig.id_fase` — UUID v4 estável, gravado no `.tres`. `garantir_id_fase()` gera na
  carga para recurso antigo (migração suave) e **avisa alto**, porque id gerado em runtime
  não pareia sessões entre execuções.
- Os geradores preservam o id já gravado ao regerar a fase — verificado: regerar duas vezes
  mantém o mesmo UUID. Trocar a identidade desemparelharia a telemetria já coletada.
- `id_fase` e `titulo_fase` viajam em **todo** evento e **toda** tentativa.
- `Sessao` guarda os dois; o `clampi` saiu.
- **Nada mais é descartado por número de fase.**

**Decisão de engenharia que diverge do texto do pedido:** o campo numérico `fase` continua
indo como `null` fora de 1..4. Não é amarra do cliente — é que o `CHECK (fase BETWEEN 1
AND 4)` ainda existe no banco de produção, e um valor fora da faixa faz a API recusar o
**lote inteiro** (4xx = erro permanente = lote descartado), levando junto centenas de
registros válidos. Ou seja: mandar o número "livre" hoje perderia exatamente o dado que a
mudança quer salvar. A identidade real está em `id_fase`, e quando o `CHECK` cair é uma
linha para remover, já marcada em comentário. Contrato para o time do banco na seção 0 de
`docs/contrato-telemetria.md`.

## 3. Dashboard de Telemetria (Figura 7)

Tela nova, `cenas/ui/dashboard_telemetria.tscn`, ligada ao botão "Telemetria":

- **acertos × erros** em barras desenhadas com `_draw` (duas barras não pagam uma
  dependência nova, e `_draw` dá controle total do contraste);
- **tempo de resolução por fase**, rotulado por `titulo_fase`/`id_fase` — nunca "Nível 1/2"
  fixo, que mentiria na primeira fase criada;
- **exportar JSON** — drena a fila antes, para não exportar retrato incompleto, e grava
  `user://resumo_telemetria.json`;
- **voltar ao menu**;
- **o painel de diagnóstico técnico não foi removido**: abre por um botão aqui dentro. Ele
  responde "a coleta está funcionando?"; o dashboard responde "o que a coleta diz".

A agregação vive em `scripts/telemetria/resumo_telemetria.gd` — lógica pura, testável sem
abrir a cena. `ABANDONO` e `TIMEOUT` não contam como erro: desistir não é errar, e somá-los
inflaria a taxa de erro com outro fenômeno.

Fonte dos dados: o JSONL do modo MOCK, que é o registro local da coleta. Em modo HTTP o
histórico está no servidor e a tela **diz isso**, em vez de mostrar um gráfico zerado como
se não houvesse dado.

## 4. Revisão geral

- **Opacidade (o bug histórico):** os `PanelContainer` do terminal, da caixa de puzzle, do
  painel da cifra e da tela de captura usavam o `StyleBox` **padrão do tema, que é
  semitransparente**. Todos ganharam `StyleBoxFlat` opaco explícito. O dashboard já nasceu
  assim, com teste que falha se o fundo não for opaco.
- **Código morto:** saíram os `@onready` órfãos do menu e o painel de telemetria duplicado
  (migrou para o dashboard). `LegendaCores` foi reduzido, não apagado.
- **Warnings:** importação limpa, sem aviso do editor.
- **Suíte:** **196 testes, 1109 verificações, 0 falhas** (era 180/1047). Arquivos novos:
  `teste_telemetria_global.gd` (6) e `teste_dashboard.gd` (8), mais 2 em `teste_modo_humano`
  (21) travando a remoção do tutorial **e** a sobrevivência da cor e do aviso de proteção.
- `teste_transporte_http.gd` e `teste_resiliencia_http.gd` continuam **sem rodar** (exigem
  `python`, ausente nesta máquina); nada aqui toca o transporte HTTP.

## 5. Como testar à mão

1. **Menu:** só "jogar", "telemetria" e "sair" — sem tutorial de cores e sem buraco no
   layout.
2. **Jogar uma fase:** os cachorros continuam coloridos; a HUD mostra "Cesar ativa 9.4s" em
   branco ao cifrar; ser pego mostra "este interceptador lê Cesar" (sem citar cor).
3. **Telemetria com fase fora de 1..4:** abra `tools/gerar_fase_01.gd`, troque
   `config.numero` para 3 e regere — ou rode `tests/runner.gd -- telemetria_global`, que
   cobre fase 97 e fase 42. Os eventos **não** são descartados e carregam `id_fase`.
4. **Dashboard:** menu → "telemetria". Deve mostrar sessões, taxa de acerto, as duas barras
   e a tabela por fase. "exportar JSON" grava `resumo_telemetria.json` na pasta `user://` e
   informa o caminho completo no rodapé. "diagnóstico" abre o painel técnico de sempre.
5. **Opacidade:** abra o terminal (`T`), a caixa de puzzle e a tela de captura com o
   labirinto atrás — nenhum deve deixar o mapa aparecer através do painel.

---
---

# Editor visual de fases (construção)

**Data:** 2026-09-16 · **Branch:** `reconstrucao-editor` · **ADR:** [0011](docs/decisoes/0011-editor-visual-de-fases.md)

## 0. A perda não se confirmou — é construção, não restauração

O pedido dizia que o commit `5b443f5` apagou um editor de fases. **A apuração do Git mostra
que não:**

- `5b443f5` **não apagou nenhum arquivo** (`--diff-filter=D` vazio); alterou dois.
- As 126 + 82 linhas removidas foram, textualmente, o `PainelTutorial` (legenda de cores) e o
  `PainelTelemetria` de diagnóstico — que não sumiu, migrou para dentro do dashboard. Os
  números batem com o pedido porque era exatamente isso que aquelas linhas eram.
- `git log --all -S` por `CarregadorFaseJson`, `user://fases` e `FileDialog`: **zero
  ocorrências em toda a história**. `scripts/geracao/` nunca existiu; nenhum arquivo de editor
  foi adicionado em commit algum. Os dois *dangling commits* do `fsck` são versões antigas do
  commit "conteudo:", de um cherry-pick.

O editor nunca esteve neste repositório. Foi construído agora, do zero, sobre o motor que
sobreviveu (que estava intacto). Registrado no ADR 0011 para quem auditar o histórico depois.

## 1. O que foi construído, por etapa

| Commit | Entrega |
|---|---|
| `cbfdb54` | `GeradorDeMapa` + `CarregadorFaseJson` + `modo_de_bloqueio` no motor + fase de exemplo |
| `cc4369f` | Menu reorganizado + tela de seleção (jogar, excluir) + `IniciadorDeFase` |
| `6b2ad85` | Editor visual (criar, editar, salvar, round-trip) |
| *(este)* | Subir e exportar `.json` |

**Nota de honestidade:** as Etapas 3 e 4 do pedido saíram no mesmo commit. Editar não é código
separado de criar — é a mesma tela carregada a partir de um arquivo, e o round-trip é uma
propriedade desse mesmo código. Cheguei a criar um commit vazio para marcar a Etapa 4 e o
removi: commit sem diff alega trabalho que não existe.

## 2. Decisões que valem citar

- **O JSON é transporte de um `FaseConfig`**, não um segundo modelo. Validação pelas mesmas
  funções `problemas()` do jogo — não há duas noções de "fase válida" para divergir.
- **O mapa viaja como semente**, não desenhado: `{largura, altura, seed}`. Mesma semente =
  mesmo labirinto, então a fase testada é a fase jogada. A semente sorteada volta gravada ao
  salvar (manter `seed: 0` faria cada abertura sortear outro mapa).
- **"Sempre solucionável" é verificação, não promessa:** o mapa só sai do gerador depois de
  passar por `MapaConfig.problemas()`; falhando, tenta a próxima semente e, no limite, devolve
  erro em vez de labirinto quebrado.
- **Braiding (75% dos becos viram ciclo):** labirinto perfeito encurrala quem foge e torna a
  fuga sorte. Com ciclos, dar a volta no perseguidor é decisão — a vibe Pac-Man pedida.
- **Três modos de bloqueio explícitos** (`CIFRA` | `COMANDO` | `NENHUM`), não inferidos de
  "o comando está vazio?". "Não tem comando porque usa cifra" e "não tem comando porque só
  persegue" são coisas diferentes, e inferir faria a validação cobrar cifra de um vigia que
  nunca foi feito para ser enganado.
- **`id_fase` nunca muda** ao editar, exportar ou subir: é a chave que liga fase ↔ telemetria.
  Com teste em cada caminho.

## 3. Nada do que existia regrediu

As fases 1–3 continuam funcionando pelo caminho antigo (cenas + `.tres`, proteção por cifra).
Telemetria global, dashboard, cripto, navegação, A\*, Diretor e a pausa do terminal: intactos.
O único ajuste no motor foi relaxar `FaseConfig.problemas()` para não exigir desafio de
terminal quando nenhum vigia depende de cifra — as fases do TCC seguem exigindo.

**Suíte: 254 testes, 1347 verificações, 0 falhas** (era 196/1109). Arquivos novos:
`teste_fases_json.gd` (14), `teste_selecao_de_fases.gd` (7), `teste_editor_de_fase.gd` (8).

`teste_transporte_http.gd` e `teste_resiliencia_http.gd` continuam **sem rodar** (precisam de
`python`, ausente nesta máquina); nada aqui toca o transporte HTTP.

## 4. Teste manual completo

1. **Criar:** menu → *criar fase*. Preencha título, briefing, vidas. Em *vigias*, escolha uma
   cor e escreva `trocar senha`; adicione um segundo vigia e **deixe o comando em branco**
   (esse só persegue). Em *terminais*, escreva uma pergunta, duas opções, marque a correta.
   *Salvar* → deve aparecer "fase salva em …".
2. **Validação:** apague o título e *salvar* de novo — não grava, e o erro aparece na tela.
3. **Jogar:** menu → *escolher fase* → selecione a sua → *jogar*. No labirinto, abra o
   terminal (`T`) e digite `trocar senha`: o vigia daquela cor deixa de te pegar por alguns
   segundos; o outro continua perigoso. Colete os terminais e atravesse a porta.
4. **Editar:** volte, *editar* a mesma fase — os campos devem vir **preenchidos**, com os dois
   vigias e a pergunta. Mude o briefing, salve: **nenhum arquivo novo** deve aparecer na lista.
5. **Exportar / subir:** *exportar* para a Área de Trabalho; depois menu → *subir fase* e
   escolha esse arquivo. A fase deve ser aceita e aparecer na lista (com sufixo, se o título
   colidir). Tente subir um `.txt` qualquer renomeado para `.json`: deve ser **recusado** com
   o motivo.
6. **Excluir:** selecione e *excluir* — pede confirmação e some da lista.
7. **Telemetria:** menu → *telemetria*. A fase criada deve aparecer na tabela pelo título, com
   o `id_fase` ligando os eventos. Confirme que nenhuma tela (editor, seleção, dashboard,
   terminal, puzzle) deixa o fundo aparecer através do painel.

---
---

# Editor em abas, passe visual e perguntas sem cor

**Data:** 2026-09-20 · **Branch:** `feature/editor-abas-e-limpeza` (3 commits, um por parte)

Não havia `.git` neste diretório (só `.gitattributes`/`.gitignore`) — o histórico começa
com um commit `chore: estado inicial do cliente Godot (baseline)` antes desta tarefa, para
toda mudança real ficar em commits separados e revisáveis.

## 1. Editor em abas

`editor_de_fase.tscn` trocou o scroll vertical único por um `TabContainer` (geral /
cachorros / perguntas), com a área de erros e os botões salvar/salvar e jogar/voltar fixos
fora das abas — o erro de validação aparece não importa em qual aba o professor esteja.
`montar_dicionario()`, `_salvar()`, `_carregar()`, `_mostrar_erros()` não mudaram, só os
`NodePath` dos campos. Troca de aba foca o primeiro campo relevante (título; comando do
primeiro vigia; enunciado do primeiro terminal). Teste novo
(`teste_trocar_de_aba_nao_perde_dado_digitado`) passeia pelas três abas com dados
preenchidos e confere que nada se perde — é o risco central desta mudança.

## 2. Passe visual

O levantamento mostrou que o bug histórico de painel transparente **já não existe em
nenhuma tela** — todas já eram opacas e a paleta escura já era consistente. O trabalho real
foi diferenciar botões destrutivos (remover vigia/opção/terminal no editor, "excluir" na
seleção de fases) com a mesma cor de alerta do painel de erros, e separadores marcando
fronteira de seção. Para não depender de inspeção visual manual daqui pra frente,
`tests/teste_telas_opacas.gd` varre toda cena por inteiro (não caminhos fixos de nó) e
falha se algum painel de conteúdo perder a opacidade — distinguindo telas de página inteira
de overlays de jogo (`tela_captura`, `caixa_puzzle`), cujo `ColorRect` de fundo é um véu
translúcido *de propósito* sobre o labirinto ainda rodando.

## 3. Perguntas sem cor (pendência 5 do doc de conformidade)

Quatro textos das fases 1–3 ainda dependiam da legenda cor→cifra removida da interface:
duas perguntas de múltipla escolha identificavam o interceptador pela cor
(`"um cachorro VERDE ronda..."`, opção `"a cor do cachorro que está perseguindo"`) e dois
desafios de revisão citavam a cor como flavor text. Reescritos para serem respondíveis só
com o que a fase já ensinou até aquele ponto (ex.: a pergunta de aplicação da fase 2 vira
"você já tentou a cifra nova e ainda foi pego — qual das duas cifras que você conhece resta
tentar?", em vez de identificar o vigia pela cor). `tools/gerar_fase_0{1,2,3}.gd` e os
`.tres` publicados foram editados em conjunto — o `.tres` é texto puro, então deu para
manter os dois sincronizados sem reabrir o editor Godot. `pacote_config.gd` tinha um
comentário desatualizado dizendo que os botões de resposta saem coloridos; corrigido —
`caixa_puzzle.gd` já garantia o contrário de propósito ("nenhuma opção é colorida, nem
quando é nome de algoritmo"). `tests/teste_perguntas_sem_cor.gd` varre os três `.tres`
publicados e falha se qualquer campo de texto voltado ao jogador citar nome de cor.

## 4. Verificação geral

- **Fluxos de navegação:** seleção de fases, editor, menu e dashboard já tinham volta e
  ação completas antes desta tarefa; nenhum botão morto ou sinal desconectado nesses
  caminhos.
- **Sinais declarados sem nenhum listener em lugar nenhum do repositório** (produção ou
  teste): `Cachorro.destino_alcancado`, `Jogador.protecao_expirou`,
  `FaseBase.fase_concluida`/`fase_abandonada`, `PainelCifra.aberto`/`fechado`. Não removidos
  — podem ser API pública intencional (ex.: para um `RemoteTrigger`/agente de RL futuro) —
  mas ficam listados para quem quiser confirmar se ainda fazem sentido.
- **Fase de exemplo:** `CarregadorFaseJson.semear_exemplo()` só grava se a pasta estiver
  vazia; a lista nunca abre vazia. Sem mudança necessária.
- **`print()` solto:** nenhum fora de `scripts/nucleo/registro.gd` (o próprio logger).
- **Suíte de testes — achado fora do escopo desta tarefa:** rodando neste ambiente (Godot
  4.6.2.stable, primeira importação, sem `.godot/` prévio) aparecem falhas que **já
  existiam no commit anterior a esta tarefa** (confirmado rodando a mesma suíte, sem
  nenhuma mudança, nesse commit): `teste_astar` (55/100 mapas com custo divergente entre
  `AStarGrid2D` e a referência), `teste_cenas::teste_tileset_tem_a_camada_solido`
  (`labirinto.tres` não carrega), e falhas de timing em `teste_fase_01_integracao`,
  `teste_fase_02_integracao` e `teste_modo_humano`. Nenhuma delas é causada pelo editor em
  abas, pelo passe de estilo ou pela correção das perguntas — nada nesta tarefa toca
  `scripts/ia/` nem os `.tres` de tileset. Hipótese mais provável: descompasso entre a
  versão de Godot usada quando a suíte foi medida em "254 testes, 0 falhas" (sessão de
  2026-09-16) e o 4.6.2 usado agora. Não investigado por estar fora do escopo — registrado
  em `docs/conformidade-monografia.md`, pendência 6.
- **Teste de integração HTTP:** ao contrário do que o doc de conformidade dizia, `python`
  **está** disponível nesta máquina, e `teste_transporte_http.gd` +
  `teste_resiliencia_http.gd` passam quando rodados isoladamente. Rodar a suíte inteira
  numa única invocação do runner travou sem terminar (processo parado, sem progredir) tanto
  antes quanto depois desta tarefa — não isolei a causa (suspeita: estado deixado por um
  arquivo anterior não é limpo antes do próximo, algo que só aparece rodando todos os ~34
  arquivos em sequência no mesmo processo). Todos os arquivos passam quando rodados um a
  um; ver `docs/conformidade-monografia.md`, pendência 2.

Todos os arquivos de teste que este trabalho tocou ou criou passam limpos, rodados
isoladamente: `teste_editor_de_fase` (9/34), `teste_telas_opacas` (2/12),
`teste_perguntas_sem_cor` (1/483), `teste_selecao_de_fases` (7/32) — nenhuma regressão nos
outros 25 arquivos de teste do projeto.

## 5. Como testar à mão

1. **Abas:** menu → *criar fase*. Confirme as três abas (geral/cachorros/perguntas), que
   trocar de aba não apaga o que foi digitado nas outras, e que o foco cai no primeiro
   campo relevante de cada aba. Tente salvar sem título: o erro aparece embaixo **não
   importa em qual aba você esteja**.
2. **Botões destrutivos:** confirme visualmente que "x" (remover vigia/opção), "remover
   terminal" e "excluir" (seleção de fases) saem na cor de alerta, distintos dos botões
   neutros.
3. **Round-trip:** monte uma fase com dois vigias e dois terminais, salve, edite de novo —
   nada deve faltar.
4. **Perguntas sem cor:** jogue as fases 1, 2 e 3 do TCC até os pacotes de aplicação; leia
   os enunciados — nenhum deve citar cor de cachorro, e todos devem ser respondíveis com o
   que a fase já ensinou até ali.
5. **Opacidade:** confirme visualmente que nenhuma tela deixa o fundo aparecer através do
   painel (checagem automatizada em `teste_telas_opacas.gd`, mas vale conferir também no
   editor rodando).
