package br.edu.purrbytes.telemetria.dominio;

import java.util.Collection;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EventoTelemetriaRepository extends JpaRepository<EventoTelemetria, UUID> {

    /**
     * Quais destes ids já foram gravados. Usado para filtrar duplicatas antes
     * do saveAll — é isso que torna o reenvio de um lote idempotente em vez de
     * gerar violação de chave primária.
     */
    @Query("select e.idEvento from EventoTelemetria e where e.idEvento in :ids")
    Set<UUID> idsExistentes(@Param("ids") Collection<UUID> ids);
}
