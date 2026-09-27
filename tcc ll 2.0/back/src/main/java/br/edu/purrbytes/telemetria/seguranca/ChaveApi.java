package br.edu.purrbytes.telemetria.seguranca;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * operacao.chave_api. Só leitura a partir da aplicação — nenhuma rota de
 * ingestão emite chave nova; isso é papel da futura rota de administração.
 */
@Entity
@Table(name = "chave_api", schema = "operacao")
public class ChaveApi {

    public static final String ESCOPO_INGESTAO = "INGESTAO";

    @Id
    @Column(name = "id_chave")
    private UUID idChave;

    @Column(name = "nome", nullable = false, length = 80)
    private String nome;

    @Column(name = "prefixo", nullable = false, length = 12)
    private String prefixo;

    @Column(name = "chave_hash", nullable = false, length = 64)
    private String chaveHash;

    @Column(name = "escopo", nullable = false, length = 20)
    private String escopo;

    @Column(name = "ativa", nullable = false)
    private boolean ativa;

    @Column(name = "expira_em")
    private Instant expiraEm;

    @Column(name = "ultimo_uso_em")
    private Instant ultimoUsoEm;

    protected ChaveApi() {
    }

    public String getEscopo() {
        return escopo;
    }

    public boolean isAtiva() {
        return ativa;
    }

    public Instant getExpiraEm() {
        return expiraEm;
    }

    public void marcarUso(Instant agora) {
        this.ultimoUsoEm = agora;
    }
}
