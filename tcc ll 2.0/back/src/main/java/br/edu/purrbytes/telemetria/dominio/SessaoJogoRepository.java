package br.edu.purrbytes.telemetria.dominio;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SessaoJogoRepository extends JpaRepository<SessaoJogo, UUID> {
}
