package br.edu.purrbytes.telemetria.ingestao;

import br.edu.purrbytes.telemetria.dominio.SessaoJogoRepository;
import br.edu.purrbytes.telemetria.dominio.TentativaComando;
import br.edu.purrbytes.telemetria.dominio.TentativaComandoRepository;
import br.edu.purrbytes.telemetria.erro.ErroDeIngestao;
import br.edu.purrbytes.telemetria.ingestao.dto.LoteTentativasRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.TentativaRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.TokenRequest;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TentativaIngestaoService {

    private final TentativaComandoRepository tentativaRepository;
    private final SessaoJogoRepository sessaoRepository;
    private final int maxEventosPorLote;

    public TentativaIngestaoService(
            TentativaComandoRepository tentativaRepository,
            SessaoJogoRepository sessaoRepository,
            @Value("${purrbytes.ingestao.max-eventos-por-lote}") int maxEventosPorLote) {
        this.tentativaRepository = tentativaRepository;
        this.sessaoRepository = sessaoRepository;
        this.maxEventosPorLote = maxEventosPorLote;
    }

    @Transactional
    public int registrarLote(UUID idSessaoNaRota, LoteTentativasRequest req) {
        List<TentativaRequest> tentativas = req.tentativas();
        if (tentativas.size() > maxEventosPorLote) {
            throw new ErroDeIngestao("lote com " + tentativas.size()
                    + " tentativas, acima do teto de " + maxEventosPorLote);
        }
        for (TentativaRequest tentativa : tentativas) {
            if (!idSessaoNaRota.equals(tentativa.idSessao())) {
                throw new ErroDeIngestao("id_sessao da rota nao bate com o de uma tentativa do lote");
            }
        }
        if (!sessaoRepository.existsById(idSessaoNaRota)) {
            throw new ErroDeIngestao("sessao inexistente; abra a sessao antes de enviar tentativas");
        }

        Set<UUID> idsJaGravados = tentativaRepository.idsExistentes(
                tentativas.stream().map(TentativaRequest::idTentativa).toList());
        List<TentativaComando> novas = tentativas.stream()
                .filter(t -> !idsJaGravados.contains(t.idTentativa()))
                .map(this::paraEntidade)
                .toList();

        tentativaRepository.saveAll(novas);
        return novas.size();
    }

    private TentativaComando paraEntidade(TentativaRequest t) {
        List<Map<String, Object>> tokens = (t.tokens() == null ? List.<TokenRequest>of() : t.tokens())
                .stream()
                .map(token -> Map.<String, Object>of(
                        "tipo", token.tipo(),
                        "lexema", token.lexema() == null ? "" : token.lexema(),
                        "posicao", token.posicao()))
                .toList();

        return new TentativaComando(t.idTentativa(), t.idSessao(), t.idFase(), t.tituloFase(), t.fase(),
                t.desafio(), t.entradaNormalizada(), tokens, t.resultado(), t.codigoErro(),
                t.tempoRespostaMs(), t.numeroTentativa(), t.ocorridoEm(), Instant.now());
    }
}
