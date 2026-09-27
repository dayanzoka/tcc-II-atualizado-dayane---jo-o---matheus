package br.edu.purrbytes.telemetria.ingestao;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import br.edu.purrbytes.telemetria.dominio.SessaoJogoRepository;
import br.edu.purrbytes.telemetria.dominio.Sujeito;
import br.edu.purrbytes.telemetria.dominio.SujeitoRepository;
import br.edu.purrbytes.telemetria.ingestao.dto.AbrirSessaoRequest;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class SessaoIngestaoServiceTest {

    @Mock
    private SessaoJogoRepository sessaoRepository;

    @Mock
    private SujeitoRepository sujeitoRepository;

    private SessaoIngestaoService servico;

    @BeforeEach
    void montar() {
        servico = new SessaoIngestaoService(sessaoRepository, sujeitoRepository);
    }

    @Test
    void abrirSessaoJaExistenteNaoGravaDeNovo() {
        // Idempotencia: o cliente reenvia o mesmo POST /v1/sessoes quando nao
        // sabe se a resposta anterior chegou. A segunda chamada nao pode
        // duplicar nem falhar.
        AbrirSessaoRequest req = new AbrirSessaoRequest(
                UUID.randomUUID(), UUID.randomUUID(), "0.1.0", "Windows", Instant.now());
        when(sessaoRepository.existsById(req.idSessao())).thenReturn(true);

        servico.abrirSessao(req);

        verify(sessaoRepository, never()).save(any());
        verify(sujeitoRepository, never()).save(any());
    }

    @Test
    void abrirSessaoNovaCriaSujeitoAutomaticoQuandoNaoExiste() {
        AbrirSessaoRequest req = new AbrirSessaoRequest(
                UUID.randomUUID(), UUID.randomUUID(), "0.1.0", "Windows", Instant.now());
        when(sessaoRepository.existsById(req.idSessao())).thenReturn(false);
        when(sujeitoRepository.existsById(req.idSujeito())).thenReturn(false);

        servico.abrirSessao(req);

        verify(sujeitoRepository, times(1)).save(any(Sujeito.class));
        verify(sessaoRepository, times(1)).save(any());
    }

    @Test
    void abrirSessaoNovaNaoRecriaSujeitoJaCadastrado() {
        AbrirSessaoRequest req = new AbrirSessaoRequest(
                UUID.randomUUID(), UUID.randomUUID(), "0.1.0", "Windows", Instant.now());
        when(sessaoRepository.existsById(req.idSessao())).thenReturn(false);
        when(sujeitoRepository.existsById(req.idSujeito())).thenReturn(true);

        servico.abrirSessao(req);

        verify(sujeitoRepository, never()).save(any());
        verify(sessaoRepository, times(1)).save(any());
    }
}
