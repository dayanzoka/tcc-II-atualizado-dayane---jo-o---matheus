package br.edu.purrbytes.telemetria.ingestao.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.time.Instant;
import java.util.UUID;

/** Corpo de {@code POST /v1/sessoes/{id}/encerrar}. */
public record EncerrarSessaoRequest(
        @NotNull UUID idSessao,
        @Pattern(regexp = "ENCERRADA|ABANDONADA", message = "deve ser ENCERRADA ou ABANDONADA") String status,
        @NotNull Instant encerradaEm
) {
}
