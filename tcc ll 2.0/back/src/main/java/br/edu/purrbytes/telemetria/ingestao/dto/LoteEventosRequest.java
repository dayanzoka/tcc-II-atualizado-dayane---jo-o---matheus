package br.edu.purrbytes.telemetria.ingestao.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public record LoteEventosRequest(@NotEmpty @Valid List<EventoRequest> eventos) {
}
