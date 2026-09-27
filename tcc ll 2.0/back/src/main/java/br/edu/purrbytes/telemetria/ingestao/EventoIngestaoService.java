package br.edu.purrbytes.telemetria.ingestao;

import br.edu.purrbytes.telemetria.dominio.EventoTelemetria;
import br.edu.purrbytes.telemetria.dominio.EventoTelemetriaRepository;
import br.edu.purrbytes.telemetria.dominio.SessaoJogoRepository;
import br.edu.purrbytes.telemetria.erro.ErroDeIngestao;
import br.edu.purrbytes.telemetria.ingestao.dto.EventoRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.LoteEventosRequest;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EventoIngestaoService {

    private static final Logger log = LoggerFactory.getLogger(EventoIngestaoService.class);

    private final EventoTelemetriaRepository eventoRepository;
    private final SessaoJogoRepository sessaoRepository;
    private final int maxEventosPorLote;
    private final int maxDefasagemMinutos;

    public EventoIngestaoService(
            EventoTelemetriaRepository eventoRepository,
            SessaoJogoRepository sessaoRepository,
            @Value("${purrbytes.ingestao.max-eventos-por-lote}") int maxEventosPorLote,
            @Value("${purrbytes.ingestao.max-defasagem-relogio-minutos}") int maxDefasagemMinutos) {
        this.eventoRepository = eventoRepository;
        this.sessaoRepository = sessaoRepository;
        this.maxEventosPorLote = maxEventosPorLote;
        this.maxDefasagemMinutos = maxDefasagemMinutos;
    }

    @Transactional
    public int registrarLote(UUID idSessaoNaRota, LoteEventosRequest req) {
        List<EventoRequest> eventos = req.eventos();
        if (eventos.size() > maxEventosPorLote) {
            throw new ErroDeIngestao("lote com " + eventos.size()
                    + " eventos, acima do teto de " + maxEventosPorLote);
        }
        for (EventoRequest evento : eventos) {
            if (!idSessaoNaRota.equals(evento.idSessao())) {
                throw new ErroDeIngestao("id_sessao da rota nao bate com o de um evento do lote");
            }
        }
        if (!sessaoRepository.existsById(idSessaoNaRota)) {
            throw new ErroDeIngestao("sessao inexistente; abra a sessao antes de enviar eventos");
        }

        Set<UUID> idsJaGravados = eventoRepository.idsExistentes(eventos.stream().map(EventoRequest::idEvento).toList());
        List<EventoTelemetria> novos = eventos.stream()
                .filter(e -> !idsJaGravados.contains(e.idEvento()))
                .map(this::paraEntidade)
                .toList();

        // Se algum tipo_evento estiver fora do catalogo (FK) ou colidir em
        // sequencia, isto estoura DataIntegrityViolationException; o
        // ManipuladorGlobalDeErros converte para 400 -- dado malformado, nao
        // falha transitoria.
        eventoRepository.saveAll(novos);

        avisarSeDefasado(novos);
        return novos.size();
    }

    private EventoTelemetria paraEntidade(EventoRequest e) {
        return new EventoTelemetria(e.idEvento(), e.idSessao(), e.sequencia(), e.tipoEvento(),
                e.idFase(), e.tituloFase(), e.fase(), e.ocorridoEm(), Instant.now(),
                e.payload() == null ? Map.of() : e.payload());
    }

    /**
     * "Aceito mas marcado", como pede docs/arquitetura/visao-geral.md — o
     * schema atual nao tem uma coluna para carimbar isso por linha, entao a
     * marca hoje e este log. Se a analise vier a precisar disso por evento, o
     * proximo passo natural e uma coluna `defasagem_suspeita boolean`.
     */
    private void avisarSeDefasado(List<EventoTelemetria> eventos) {
        Instant agora = Instant.now();
        for (EventoTelemetria evento : eventos) {
            long minutos = Math.abs(Duration.between(evento.getOcorridoEm(), agora).toMinutes());
            if (minutos > maxDefasagemMinutos) {
                log.warn("evento {} com defasagem de relogio de {} min (limite {})",
                        evento.getIdEvento(), minutos, maxDefasagemMinutos);
            }
        }
    }
}
