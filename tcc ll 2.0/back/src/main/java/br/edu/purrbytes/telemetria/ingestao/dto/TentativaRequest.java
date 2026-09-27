package br.edu.purrbytes.telemetria.ingestao.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Um elemento de {@code POST /v1/sessoes/{id}/tentativas}. */
public record TentativaRequest(
        @NotNull UUID idTentativa,
        @NotNull UUID idSessao,
        @NotNull UUID idFase,
        @Size(max = 60) String tituloFase,
        @Min(1) @Max(4) Integer fase,
        @NotBlank @Size(max = 60) String desafio,
        @NotNull @Size(max = 240) String entradaNormalizada,
        @Valid List<TokenRequest> tokens,
        @NotBlank @Pattern(regexp = "SUCESSO|ERRO_LEXICO|ERRO_SINTATICO|ERRO_SEMANTICO|TIMEOUT|ABANDONO")
        String resultado,
        @Size(max = 40) String codigoErro,
        @PositiveOrZero int tempoRespostaMs,
        @Min(1) int numeroTentativa,
        @NotNull Instant ocorridoEm
) {
}
