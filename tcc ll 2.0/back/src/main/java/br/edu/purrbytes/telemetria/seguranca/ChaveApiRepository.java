package br.edu.purrbytes.telemetria.seguranca;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ChaveApiRepository extends JpaRepository<ChaveApi, UUID> {

    Optional<ChaveApi> findByChaveHash(String chaveHash);

    boolean existsByPrefixo(String prefixo);
}
