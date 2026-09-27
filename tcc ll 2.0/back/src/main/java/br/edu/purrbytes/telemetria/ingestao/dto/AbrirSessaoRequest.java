package br.edu.purrbytes.telemetria.ingestao.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

/** Corpo de {@code POST /v1/sessoes}. Campo a campo, as colunas NOT NULL de pesquisa.sessao_jogo. */
public record AbrirSessaoRequest(
        @NotNull UUID idSessao,
        @NotNull UUID idSujeito,
        @NotBlank @Size(max = 30) String versaoJogo,
        @NotBlank @Size(max = 30) String plataforma,
        @NotNull Instant iniciadaEm
) {
}
