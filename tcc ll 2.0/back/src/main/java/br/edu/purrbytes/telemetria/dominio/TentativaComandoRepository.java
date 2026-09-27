package br.edu.purrbytes.telemetria.dominio;

import java.util.Collection;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface TentativaComandoRepository extends JpaRepository<TentativaComando, UUID> {

    @Query("select t.idTentativa from TentativaComando t where t.idTentativa in :ids")
    Set<UUID> idsExistentes(@Param("ids") Collection<UUID> ids);
}
