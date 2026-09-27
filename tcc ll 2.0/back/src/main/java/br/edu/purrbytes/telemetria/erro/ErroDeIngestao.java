package br.edu.purrbytes.telemetria.erro;

/**
 * Erro permanente de ingestão (4xx): pelo contrato do cliente Godot, qualquer
 * resposta 4xx faz o lote inteiro ser descartado, então esta exceção só deve
 * ser lançada para dados realmente malformados, nunca para falha transitória.
 */
public class ErroDeIngestao extends RuntimeException {

    public static final int STATUS_REQUISICAO_INVALIDA = 400;
    public static final int STATUS_NAO_AUTORIZADO = 401;

    private final int status;

    public ErroDeIngestao(String mensagem) {
        this(STATUS_REQUISICAO_INVALIDA, mensagem);
    }

    public ErroDeIngestao(int status, String mensagem) {
        super(mensagem);
        this.status = status;
    }

    public int getStatus() {
        return status;
    }
}
