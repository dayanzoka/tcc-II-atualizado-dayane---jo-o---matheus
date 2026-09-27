package br.edu.purrbytes.telemetria.ingestao;

import br.edu.purrbytes.telemetria.dominio.SessaoJogo;
import br.edu.purrbytes.telemetria.dominio.SessaoJogoRepository;
import br.edu.purrbytes.telemetria.dominio.Sujeito;
import br.edu.purrbytes.telemetria.dominio.SujeitoRepository;
import br.edu.purrbytes.telemetria.erro.ErroDeIngestao;
import br.edu.purrbytes.telemetria.ingestao.dto.AbrirSessaoRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.EncerrarSessaoRequest;
import java.time.Instant;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SessaoIngestaoService {

    private final SessaoJogoRepository sessaoRepository;
    private final SujeitoRepository sujeitoRepository;

    public SessaoIngestaoService(SessaoJogoRepository sessaoRepository, SujeitoRepository sujeitoRepository) {
        this.sessaoRepository = sessaoRepository;
        this.sujeitoRepository = sujeitoRepository;
    }

    @Transactional
    public void abrirSessao(AbrirSessaoRequest req) {
        if (sessaoRepository.existsById(req.idSessao())) {
            return; // idempotente: o cliente reenvia sem saber se a resposta anterior chegou
        }

        garantirSujeito(req.idSujeito());

        SessaoJogo sessao = new SessaoJogo(req.idSessao(), req.idSujeito(), req.versaoJogo(),
                req.plataforma(), req.iniciadaEm(), Instant.now());
        sessaoRepository.save(sessao);
    }

    @Transactional
    public void encerrarSessao(UUID idSessaoNaRota, EncerrarSessaoRequest req) {
        if (!idSessaoNaRota.equals(req.idSessao())) {
            throw new ErroDeIngestao("id_sessao da rota nao bate com o do corpo");
        }

        SessaoJogo sessao = sessaoRepository.findById(idSessaoNaRota)
                .orElseThrow(() -> new ErroDeIngestao("sessao inexistente; abra a sessao antes de encerra-la"));

        if (!SessaoJogo.STATUS_ABERTA.equals(sessao.getStatus())) {
            return; // idempotente: encerramento ja processado numa tentativa anterior
        }
        if (req.encerradaEm().isBefore(sessao.getIniciadaEm())) {
            // mesma restricao de ck_sessao_periodo; melhor rejeitar aqui com uma
            // mensagem clara do que deixar estourar como violacao generica de banco
            throw new ErroDeIngestao("encerrada_em anterior a iniciada_em");
        }

        sessao.encerrar(req.status(), req.encerradaEm());
        sessaoRepository.save(sessao);
    }

    /**
     * A rota de cadastro de participante (escopo ADMINISTRACAO, TCLE) ainda
     * não existe — está fora do escopo deste marco, junto com toda tela que
     * colete consentimento (ver CLAUDE.md do cliente, secao 11). Sem ela,
     * abrir uma sessao para um id_sujeito novo quebraria a FK de
     * sessao_jogo. Este metodo cria um sujeito minimo para nao travar a
     * coleta; quando a rota de administracao existir, o cadastro de verdade
     * acontece la e isto vira so uma rede de seguranca contra corrida.
     */
    private void garantirSujeito(UUID idSujeito) {
        if (sujeitoRepository.existsById(idSujeito)) {
            return;
        }
        String codigoAuto = "AUTO-" + idSujeito.toString().substring(0, 8);
        Sujeito sujeito = new Sujeito(idSujeito, codigoAuto, "UNICO", Instant.now());
        try {
            sujeitoRepository.save(sujeito);
        } catch (DataIntegrityViolationException corridaDeInsercao) {
            // outra requisicao criou o mesmo sujeito entre o existsById e o save;
            // o resultado final e o mesmo, entao so ignoramos.
        }
    }
}
