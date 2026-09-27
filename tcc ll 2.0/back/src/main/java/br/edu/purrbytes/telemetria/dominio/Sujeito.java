package br.edu.purrbytes.telemetria.dominio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * pesquisa.sujeito — participante pseudonimizado.
 *
 * <p>A API de ingestão nunca cria um sujeito "de verdade": isso é papel da rota
 * de cadastro de participante (escopo ADMINISTRACAO), que ainda não existe.
 * Esta entidade só serve para o auto-provisionamento defensivo em
 * {@code SessaoIngestaoService.garantirSujeito} — ver o comentário lá.
 */
@Entity
@Table(name = "sujeito", schema = "pesquisa")
public class Sujeito {

    @Id
    @Column(name = "id_sujeito")
    private UUID idSujeito;

    @Column(name = "codigo", nullable = false, length = 20, unique = true)
    private String codigo;

    @Column(name = "coorte", length = 60)
    private String coorte;

    @Column(name = "grupo", nullable = false, length = 20)
    private String grupo = "UNICO";

    @Column(name = "criado_em", nullable = false)
    private Instant criadoEm;

    protected Sujeito() {
        // exigido pelo JPA
    }

    public Sujeito(UUID idSujeito, String codigo, String grupo, Instant criadoEm) {
        this.idSujeito = idSujeito;
        this.codigo = codigo;
        this.grupo = grupo;
        this.criadoEm = criadoEm;
    }

    public UUID getIdSujeito() {
        return idSujeito;
    }

    public String getCodigo() {
        return codigo;
    }

    public String getCoorte() {
        return coorte;
    }

    public String getGrupo() {
        return grupo;
    }

    public Instant getCriadoEm() {
        return criadoEm;
    }
}
