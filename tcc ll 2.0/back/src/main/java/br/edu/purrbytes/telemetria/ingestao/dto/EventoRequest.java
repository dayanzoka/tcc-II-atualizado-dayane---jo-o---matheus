package br.edu.purrbytes.telemetria.ingestao.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * Um elemento de {@code POST /v1/sessoes/{id}/eventos}. {@code idFase} é
 * obrigatório desde a mudança de contrato de 2026-09-14; {@code fase} é
 * legado e nulável (o cliente só o preenche entre 1 e 4).
 */
public record EventoRequest(
        @NotNull UUID idEvento,
        @NotNull UUID idSessao,
        @PositiveOrZero long sequencia,
        @NotBlank @Size(max = 40) String tipoEvento,
        @NotNull UUID idFase,
        @Size(max = 60) String tituloFase,
        @Min(1) @Max(4) Integer fase,
        @NotNull Instant ocorridoEm,
        Map<String, Object> payload
) {
}
