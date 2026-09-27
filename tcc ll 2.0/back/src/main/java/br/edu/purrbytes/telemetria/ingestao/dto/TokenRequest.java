package br.edu.purrbytes.telemetria.ingestao.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/** Token do analisador léxico: {tipo, lexema, posicao}, ver docs/gramatica.md do cliente. */
public record TokenRequest(
        @NotNull String tipo,
        String lexema,
        @PositiveOrZero int posicao
) {
}
