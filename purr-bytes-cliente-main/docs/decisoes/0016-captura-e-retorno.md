# ADR 0016 — Captura e retorno ao início

**Data:** 2026-09-25 · **Situação:** aceita

## Contexto

Relato de jogo: "morri perto do spawn, o cachorro me cercou e já me matou de novo, e na
terceira vez ele já estava em cima de mim". Reproduzido por teste
(`tests/teste_captura_e_retorno.gd`), com três causas:

1. **Os cachorros continuavam andando durante a tela de captura.** A captura chamava
   `parar()`, que só apaga o caminho atual; o temporizador de replanejamento do A\* dava
   rota nova e todos seguiam até o jogador parado.
2. **Um segundo contato durante a tela contava outra captura.** Cercado por vários
   cachorros, o jogador perdia várias vidas de uma vez (o teste contou 5 capturas).
3. **Na volta não havia respiro.** Os cachorros ficavam onde tinham parado, muitas vezes
   perto da entrada, e o contato seguinte vinha na hora.

A tela de captura também prendia o jogador por 2,5 s sem forma de continuar. Medido: não
havia engasgo de processamento (a captura custa menos de 1 ms); o "travado" era esse tempo
fixo.

## Decisões

- **Congelar o mundo:** a captura pausa a árvore (`get_tree().paused`), o mesmo
  mecanismo do terminal e da caixa de puzzle. A tela de captura roda em
  `PROCESS_MODE_ALWAYS` para contar o tempo e ouvir o `Enter`.
- **Uma captura por vez:** contato durante a tela não conta.
- **Retorno como no Pac-Man:** o jogador volta à entrada e cada cachorro volta ao ponto
  onde nasceu. O gerador põe cada cachorro na célula mais distante de tudo o que já foi
  colocado, entrada incluída, então o retorno sempre os leva para longe.
- **Invulnerabilidade curta** (`FaseConfig.invulnerabilidade_apos_captura_s`, 2 s por
  padrão): o jogador pisca (`Tween`) e não pode ser pego. Se um cachorro ainda estiver
  encostado quando ela acaba, o contato é conferido uma vez à mão, porque `body_entered`
  não dispara de novo para quem já estava dentro da área.
- **`Enter` continua**, depois de um tempo mínimo (0,6 s) para ninguém pular a explicação
  sem querer. Sem `Enter`, a tela fecha sozinha como antes.

## Consequências

A economia de erro continua a mesma (uma vida e a penalidade de pontos por captura), mas
cada captura agora corresponde a um erro do jogador, e não à posição em que os cachorros
ficaram. Isso também deixa a telemetria mais limpa: `JOGADOR_CAPTURADO` em sequência não
infla mais a contagem.
