package br.edu.purrbytes.telemetria.ingestao;

import br.edu.purrbytes.telemetria.ingestao.dto.AbrirSessaoRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.EncerrarSessaoRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.LoteEventosRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.LoteTentativasRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * As quatro rotas de docs/contrato-telemetria.md do cliente Godot. A API
 * responde sempre 202: aceite para processar, nunca "gravei" — o cliente
 * trata 2xx como sucesso e não espera corpo de volta (ver TransporteHttp no
 * repositorio do jogo).
 */
@RestController
@RequestMapping("/v1/sessoes")
public class SessaoIngestaoController {

    private final SessaoIngestaoService sessaoService;
    private final EventoIngestaoService eventoService;
    private final TentativaIngestaoService tentativaService;

    public SessaoIngestaoController(SessaoIngestaoService sessaoService,
            EventoIngestaoService eventoService, TentativaIngestaoService tentativaService) {
        this.sessaoService = sessaoService;
        this.eventoService = eventoService;
        this.tentativaService = tentativaService;
    }

    @PostMapping
    public ResponseEntity<Void> abrir(@Valid @RequestBody AbrirSessaoRequest req) {
        sessaoService.abrirSessao(req);
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/{idSessao}/eventos")
    public ResponseEntity<Void> eventos(@PathVariable UUID idSessao, @Valid @RequestBody LoteEventosRequest req) {
        eventoService.registrarLote(idSessao, req);
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/{idSessao}/tentativas")
    public ResponseEntity<Void> tentativas(@PathVariable UUID idSessao, @Valid @RequestBody LoteTentativasRequest req) {
        tentativaService.registrarLote(idSessao, req);
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/{idSessao}/encerrar")
    public ResponseEntity<Void> encerrar(@PathVariable UUID idSessao, @Valid @RequestBody EncerrarSessaoRequest req) {
        sessaoService.encerrarSessao(idSessao, req);
        return ResponseEntity.accepted().build();
    }
}
