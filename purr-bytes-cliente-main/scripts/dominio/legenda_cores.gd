class_name LegendaCores
extends RefCounted

## Nome e cor padrao de cada algoritmo.
##
## O que este arquivo JA FOI: a "legenda de cores" que ensinava a regra
## "a cor do cachorro diz qual cifra usar". Essa regra saiu do jogo -- a cor
## passou a ser identidade visual do cachorro (CachorroConfig.cor), escolhida
## livremente e destinada a virar sprite. Com ela sairam o tutorial do menu, a
## HUD colorida e as explicacoes por cor.
##
## O que sobrou tem dois papeis, os dois vivos:
##   nome()    -- como o algoritmo se escreve na tela ("SHA-256", nao "SHA256").
##                Usado no terminal, na HUD, na tela de captura e nos botoes de
##                resposta do puzzle.
##   cor()     -- a cor PADRAO de um algoritmo, usada so como default de
##                CachorroConfig.cor quando ninguem escolheu uma.
##   conhece() -- se um codigo de algoritmo existe, usado pelas validacoes de
##                FaseConfig, DesafioConfig e PacoteConfig.
##
## Os codigos sao os mesmos de FaseConfig.algoritmo (que espelha o enum do
## banco) -- nao ha um vocabulario separado para manter.

const ALGORITMOS: PackedStringArray = ["CESAR", "VIGENERE", "SHA256", "AES"]

const _COR_PADRAO: Color = Color(0.85, 0.85, 0.85)

## Cores escolhidas para se distinguirem tambem em monitor ruim de laboratorio
## escolar: matizes bem separados e luminosidade parecida, para nenhuma delas
## sumir no fundo escuro do labirinto. Sao apenas um default agradavel -- quem
## define a aparencia de um cachorro e o CachorroConfig dele.
const _CORES: Dictionary = {
	"CESAR": Color(0.42, 0.85, 0.45),
	"VIGENERE": Color(0.40, 0.66, 1.0),
	"SHA256": Color(0.74, 0.50, 0.96),
	"AES": Color(1.0, 0.66, 0.30),
}

const _NOMES: Dictionary = {
	"CESAR": "Cesar",
	"VIGENERE": "Vigenere",
	"SHA256": "SHA-256",
	"AES": "AES",
}


static func cor(algoritmo: String) -> Color:
	return _CORES.get(algoritmo, _COR_PADRAO)


static func nome(algoritmo: String) -> String:
	return String(_NOMES.get(algoritmo, algoritmo))


static func conhece(algoritmo: String) -> bool:
	return _CORES.has(algoritmo)
