package br.edu.purrbytes.telemetria.dominio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * pesquisa.sessao_jogo.
 *
 * <p>{@code idSujeito} fica como UUID simples, não como relacionamento
 * {@code @ManyToOne}: a API de ingestão nunca precisa navegar de sessão para
 * sujeito dentro de uma requisição, só gravar e conciliar por id. Uma
 * associação JPA aqui adicionaria carregamento e cache sem nenhum uso real.
 */
@Entity
@Table(name = "sessao_jogo", schema = "pesquisa")
public class SessaoJogo {

    public static final String STATUS_ABERTA = "ABERTA";

    @Id
    @Column(name = "id_sessao")
    private UUID idSessao;

    @Column(name = "id_sujeito", nullable = false)
    private UUID idSujeito;

    @Column(name = "versao_jogo", nullable = false, length = 30)
    private String versaoJogo;

    @Column(name = "plataforma", nullable = false, length = 30)
    private String plataforma;

    @Column(name = "iniciada_em", nullable = false)
    private Instant iniciadaEm;

    @Column(name = "encerrada_em")
    private Instant encerradaEm;

    @Column(name = "status", nullable = false, length = 20)
    private String status = STATUS_ABERTA;

    @Column(name = "recebida_em", nullable = false)
    private Instant recebidaEm;

    protected SessaoJogo() {
    }

    public SessaoJogo(UUID idSessao, UUID idSujeito, String versaoJogo, String plataforma,
            Instant iniciadaEm, Instant recebidaEm) {
        this.idSessao = idSessao;
        this.idSujeito = idSujeito;
        this.versaoJogo = versaoJogo;
        this.plataforma = plataforma;
        this.iniciadaEm = iniciadaEm;
        this.recebidaEm = recebidaEm;
    }

    public UUID getIdSessao() {
        return idSessao;
    }

    public Instant getIniciadaEm() {
        return iniciadaEm;
    }

    public String getStatus() {
        return status;
    }

    public void encerrar(String status, Instant encerradaEm) {
        this.status = status;
        this.encerradaEm = encerradaEm;
    }
}
