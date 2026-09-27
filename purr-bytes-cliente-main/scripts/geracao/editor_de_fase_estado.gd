class_name EditorDeFaseEstado
extends RefCounted

## Um caminho de arquivo que precisa atravessar uma troca de tela.
##
## change_scene_to_file() nao aceita parametro. Em vez de criar um autoload
## inteiro para carregar uma String, esta classe guarda o estado numa `static
## var` -- vive enquanto o jogo vive, e some com ele.
##
## Vazio = o editor abre em branco (criar fase). Preenchido = o editor abre o
## arquivo indicado (editar fase). Quem le limpa depois de usar, para que voltar
## ao editor pelo botao "criar" nao reabra a fase anterior por engano.

static var caminho_para_editar: String = ""


## Le e limpa numa operacao so: o valor e de uso unico por construcao.
static func consumir_caminho() -> String:
	var caminho: String = caminho_para_editar
	caminho_para_editar = ""
	return caminho
