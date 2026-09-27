# ADR 0017 — Segunda passada visual: paleta "fofa", fonte pixelada, gato descansando e menu com wallpaper

**Data:** 2026-09-26 · **Situação:** aceita

## Contexto

Depois da primeira repaginação (laranja/creme, ver histórico de desenvolvimento),
a Day pediu uma segunda passada: paleta amarelo pastel + branco + preto em vez de
laranja, fonte pixelada, labirinto mais claro durante a fase (estava escuro demais),
o gato sentando e "fechando o olhinho" depois de 10s sem input, e um menu principal
com mais capricho — com o wallpaper de céu noturno que ela mandou, em tons de
azul escuro/cinza (diferente do resto do jogo, de propósito).

## Decisões

### 1. Paleta: só troca de cor, não de estrutura

`recursos/temas/tema_purrbytes.tres` e os `theme_override_colors`/`border_color`
espalhados pelas cenas (que a Fase A já tinha introduzido por cima do Theme) foram
recoloridos de laranja/creme para amarelo pastel (`#FFD97B` base) + branco +
preto suave (`#25211B`, nunca preto puro — combina mais com o estilo "fofo").
Nenhum StyleBox, margem ou raio de canto mudou de estrutura, só a cor.

**O que NÃO mudou, de propósito:** as cores de MECÂNICA (`COR_ACERTO`/`COR_ERRO` do
dashboard, o anel de cor de cada cachorro, a legenda da cifra, os estados de
porta/pacote). Essas cores carregam informação de jogo, não são decoração.

### 2. Fonte pixelada: Silkscreen (SIL Open Font License), via npm

`@fontsource/silkscreen` (licença OFL — livre para redistribuir) foi baixado via
`npm pack` e o arquivo `silkscreen-latin-400-normal.woff` (cobre `U+0000-00FF`,
que inclui todos os acentos do português: ç, ã, õ, á, é, í, ó, ú, com e sem
maiúscula) foi copiado para `recursos/fontes/silkscreen_regular.woff` — o peso
700 também está em `silkscreen_bold.woff`, sem uso ainda. Referenciado como
`default_font` tanto em `tema_purrbytes.tres` (jogo todo) quanto em
`tema_menu_principal.tres` (menu). É um FontFile vetorial com desenho de letra em
blocos — não é bitmap — então qualquer tamanho de fonte já sai com cara de pixel
art, sem precisar de múltiplo de grade nenhum.

Pendência para quem abrir no editor: por padrão o Godot importa a fonte com
antialiasing ligado. Para o efeito 100% "pixelado" (sem suavização nenhuma), abra
a aba de importação do arquivo `.woff` e mude **Antialiasing** e **Hinting** para
**None** — não dá para deixar isso pré-configurado num `.import` escrito à mão com
segurança sem o editor gerar o arquivo primeiro.

### 3. O labirinto escuro era a arte placeholder, não um bug de engine

Investigação: `project.godot` não tem `clear_color` nem `environment` customizado.
O culpado real é `recursos/arte/tiles_placeholder.png` — o piso era um azul-marinho
quase preto (`#181B28`) sólido, e a parede um azul acinzentado (`#344460`) só um
pouco mais claro. Baixíssimo contraste entre os dois, e nada "fofo".

Recolorido (script único, não retocado à mão): piso virou amarelo pastel claro
sólido (`#FFF1C7`), parede virou preto quente (`#282218`) preservando a MESMA
estrutura de bisel de 3 tons que já existia (base/realce/sombra), só remapeando a
cor. É o mesmo placeholder de 2 tiles que o Marco 0 já documentava como
substituível — trocar pela pixel art definitiva do labirinto continua sendo só
trocar a textura, as coordenadas do atlas não mudaram.

### 4. Gato descansando: comportamento real, sprite é um compromisso assumido

`Jogador._atualizar_descanso()` mede tempo sem NENHUM input de movimento (o vetor
bruto de `Input.get_vector`, não a velocidade já suavizada pelo lerp — o que conta
é a intenção do jogador, não a inércia do corpo freando). Depois de
`tempo_sem_entrada_para_descansar_s` (10s, `@export`) chama
`AnimadorDirecional.descansar()`, que só troca de animação se a `SpriteFrames`
tiver `"descansar"` — por isso o Cachorro (mesmo script, regra de ouro da seção 3
do CLAUDE.md) nunca entra nesse estado: ninguém chama `descansar()` nele.

`gato_frames.tres` ganhou a animação `"descansar"`: um quadro só, o mais
assentado dos 4 de `"parado"`, sem loop de respiração. **Não existe arte de "olho
fechado"** — os 20 quadros da folha (`recursos/arte/gato.png`, 96×120) já estavam
inteiramente ocupados pelas 5 animações originais, e o rosto do gato em 24×24 é
abstrato demais (tons de focinho/branco, sem um pixel de "olho" isolado e
identificável) para editar às cegas sem risco de sair uma mancha em vez de uma
expressão. Em vez de arriscar isso, o gato senta parado e um indicador "zzz"
(`Label` novo em `jogador.tscn`, pulsando bem devagar com `Tween` — mesmo padrão
já usado em `piscar()`) aparece por cima dele enquanto descansa. Quando alguém
desenhar o quadro de olho fechado de verdade, trocar é só apontar
`"descansar"` para essa nova textura em `gato_frames.tres` — o código já está
pronto para isso.

### 5. Menu principal: `Theme` próprio + wallpaper, sem afetar o resto do jogo

`Theme` em Godot cascateia pela árvore de nós a partir de onde é atribuído. Por
isso o menu ganhou seu PRÓPRIO `tema_menu_principal.tres` (azul-cinza escuro,
`#343B4A` a `#25202D`, texto quase-branco) atribuído só na raiz de
`menu_principal.tscn` — o resto do jogo continua lendo `tema_purrbytes.tres`
(amarelo pastel) do `project.godot`, sem qualquer interferência entre os dois.

O `ColorRect` de fundo virou `TextureRect` com o wallpaper (céu noturno, estrelas,
nuvens em camadas — gerado por script em `recursos/arte/wallpaper_menu.png`, no
mesmo estilo pixel art do resto da arte, 640×360 para bater com a resolução base
do projeto). Os botões e o título foram reorganizados dentro de um novo
`PanelContainer` ("Cartão") para não ficarem soltos por cima do céu.

**Restrição herdada e respeitada:** `tests/teste_telas_opacas.gd` proíbe qualquer
painel de conteúdo translúcido em tela de página inteira (bug histórico do
projeto). O `StyleBoxFlat` do Cartão é opaco (`bg_color.a = 1.0`) por causa disso
— e também porque, por cima de um céu cheio de estrela, painel opaco lê melhor
mesmo.

## Consequências

- Nenhuma cor de mecânica de jogo mudou; só chrome/decoração.
- `tests/teste_modo_humano.gd` e `tests/teste_selecao_de_fases.gd` tiveram os
  caminhos `Coluna/Botoes/...` atualizados para `Cartao/Coluna/Botoes/...`
  (a árvore do menu ganhou um nível a mais, o `PanelContainer`).
- `tests/teste_sprites.gd` não muda: o teste chama `AnimadorDirecional.atualizar()`
  direto, sem passar pelo timer de inatividade do `Jogador`.
- Pendência de arte: um quadro de "gato sentado de olho fechado" de verdade, se
  algum dia alguém desenhar, entra em `gato_frames.tres` sem tocar em código.

## Adendo (mesmo dia) — `parado` virou pé, `descansar` virou o sentado; wallpaper e tema escuro nas outras telas

A primeira versão deste ADR reaproveitou o quadro sentado (o antigo `"parado"`)
tanto para a pausa breve quanto para o descanso de 10s+ — os dois ficavam iguais,
e a Day relatou "o gatinho está sentando toda hora". Causa raiz: `"parado"` **já
era** uma pose sentada desde a arte original (ADR 0013 chama o quadro de
"sentado" explicitamente), então toda vez que o jogador soltava a tecla por um
instante — o que acontece o tempo todo — o gato parecia estar descansando, sem
ter passado nenhum segundo.

Correção em `gato_frames.tres`: as duas animações trocaram de papel.
`"parado"` agora é um quadro só, em pé, de frente (reaproveita o primeiro quadro
de `"andar_baixo"`, sem precisar de arte nova) — é o que aparece em qualquer
pausa curta, inclusive ao nascer. `"descansar"` passou a usar o ciclo sentado de
4 quadros que antes era o `"parado"` (mesmo asset, papel invertido, mais devagar:
`speed 1.5` em vez de `3.0`), e só entra depois dos 10s de verdade, com o "zzz"
por cima. Nenhuma linha de `jogador.gd` ou `animador_direcional.gd` mudou — o
bug era só de mapeamento de quadro, não de lógica de estado.

O gatinho decorativo do menu principal (`Cartao/Coluna/Mascote/Gato` em
`menu_principal.tscn`) é um `AnimatedSprite2D` cru, sem `Jogador` nem
`AnimadorDirecional` por trás, então ganhou seu próprio timer em
`menu_principal.gd`: conta em `_process()` o tempo desde o último evento de
mouse/teclado (`_input()`, não `_gui_input()` — atividade em qualquer canto do
menu conta, não só sobre o gato) e troca para `"descansar"` depois de
`tempo_sem_entrada_para_descansar_s`, voltando para `"parado"` no primeiro input.

Também nesta rodada: a Day pediu o MESMO padrão azul-cinza escuro do menu
principal nas outras telas de navegação (seleção de fases, editor de fase,
dashboard de telemetria — não no menu, que já estava do jeito que ela queria), com
o wallpaper que ela anexou (um céu noturno com lua, mais realista/suave que o
gerado por script do menu — por isso ganhou `texture_filter = Linear` em vez do
`Nearest` padrão do projeto, para não serrilhar). `tema_menu_principal.tres` foi
renomeado para `tema_telas_secundarias.tres` (deixou de ser exclusivo do menu) e
ganhou os estilos que faltavam para cobrir essas telas por completo: `LineEdit`,
`ItemList`, `TabContainer`, `TextEdit`, `SpinBox`, `CheckBox`, `RichTextLabel`.

Cada uma dessas 3 cenas também tinha `StyleBoxFlat` **inline** (não vindo do
Theme) nos seus `PanelContainer` internos (`Raiz`, mais `PainelFases` /
`PainelDetalhe` / `PainelDiagnostico` no dashboard) e cores de texto
`theme_override_colors` fixas por nó — nenhum dos dois é tocado por trocar o
`Theme` da cena, então foram recoloridas à mão para o mesmo azul-cinza escuro.
As cores SEMÂNTICAS (`COR_ACERTO`/`COR_ERRO` do gráfico do dashboard, texto de
ajuda, texto de aviso) só clarearam de tom — verde continua verde, vermelho
continua vermelho — porque os tons antigos foram calibrados para fundo branco e
ficariam ilegíveis em cima do azul-cinza escuro.

**Overlays de jogo (`tela_captura`, `caixa_puzzle`, `painel_cifra`, `terminal`)
ficaram de fora, de propósito**: continuam com o véu translúcido + tema pastel
originais, porque não são telas de navegação — são HUD por cima do labirinto
ainda rodando, e `tests/teste_telas_opacas.gd` já separa essa categoria da de
"tela de página inteira".
