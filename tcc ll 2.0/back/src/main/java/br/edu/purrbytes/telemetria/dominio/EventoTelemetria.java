package br.edu.purrbytes.telemetria.dominio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/**
 * pesquisa.evento_telemetria.
 *
 * <p>{@code idFase}/{@code tituloFase} são a identidade real da fase desde a
 * mudança de contrato de 2026-09-14 (ver contrato-telemetria.md no repositório
 * do cliente Godot). {@code fase} (1..4) continua existindo só como legado:
 * o cliente manda {@code null} fora dessa faixa para não esbarrar no
 * {@code ck_evento_fase} de V2, e por isso esta coluna nunca deve ser usada
 * como chave de agrupamento — {@code idFase} é quem cumpre esse papel agora.
 */
@Entity
@Table(name = "evento_telemetria", schema = "pesquisa")
public class EventoTelemetria {

    @Id
    @Column(name = "id_evento")
    private UUID idEvento;

    @Column(name = "id_sessao", nullable = false)
    private UUID idSessao;

    @Column(name = "sequencia", nullable = false)
    private long sequencia;

    @Column(name = "tipo_evento", nullable = false, length = 40)
    private String tipoEvento;

    @Column(name = "id_fase", nullable = false)
    private UUID idFase;

    @Column(name = "titulo_fase", length = 60)
    private String tituloFase;

    @Column(name = "fase")
    private Integer fase;

    @Column(name = "ocorrido_em", nullable = false)
    private Instant ocorridoEm;

    @Column(name = "recebido_em", nullable = false)
    private Instant recebidoEm;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "payload", nullable = false)
    private Map<String, Object> payload;

    protected EventoTelemetria() {
    }

    public EventoTelemetria(UUID idEvento, UUID idSessao, long sequencia, String tipoEvento,
            UUID idFase, String tituloFase, Integer fase, Instant ocorridoEm, Instant recebidoEm,
            Map<String, Object> payload) {
        this.idEvento = idEvento;
        this.idSessao = idSessao;
        this.sequencia = sequencia;
        this.tipoEvento = tipoEvento;
        this.idFase = idFase;
        this.tituloFase = tituloFase;
        this.fase = fase;
        this.ocorridoEm = ocorridoEm;
        this.recebidoEm = recebidoEm;
        this.payload = payload;
    }

    public UUID getIdEvento() {
        return idEvento;
    }

    public Instant getOcorridoEm() {
        return ocorridoEm;
    }
}
