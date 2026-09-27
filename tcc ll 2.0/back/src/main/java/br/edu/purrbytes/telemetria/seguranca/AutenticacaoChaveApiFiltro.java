package br.edu.purrbytes.telemetria.seguranca;

import br.edu.purrbytes.telemetria.erro.ErroDeIngestao;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Verifica {@code Authorization: Bearer <chave>} nas rotas de ingestão contra
 * {@code operacao.chave_api}, escopo {@code INGESTAO}. A chave embutida no
 * cliente Godot é pública por contrato (restrição 8 do CLAUDE.md do jogo) —
 * ela só escreve — mas ainda assim nunca é logada aqui, nem em caso de erro.
 *
 * <p>Registrado via {@link SegurancaConfig} com {@code FilterRegistrationBean}
 * (não é {@code @Component}) para ficar restrito às rotas de ingestão — um
 * filtro de segurança em {@code /*} inteiro cobriria também {@code /actuator/
 * health}, que precisa continuar público para o orquestrador de contêiner.
 */
public class AutenticacaoChaveApiFiltro extends OncePerRequestFilter {

    private static final String PREFIXO_BEARER = "Bearer ";

    private final ChaveApiRepository chaveApiRepository;
    private final ObjectMapper objectMapper;

    public AutenticacaoChaveApiFiltro(ChaveApiRepository chaveApiRepository, ObjectMapper objectMapper) {
        this.chaveApiRepository = chaveApiRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
            FilterChain chain) throws IOException, ServletException {

        String cabecalho = request.getHeader("Authorization");
        if (cabecalho == null || !cabecalho.startsWith(PREFIXO_BEARER)) {
            recusar(response, "cabecalho Authorization ausente ou fora do formato Bearer");
            return;
        }

        String chaveEmClaro = cabecalho.substring(PREFIXO_BEARER.length()).trim();
        if (chaveEmClaro.isEmpty()) {
            recusar(response, "chave vazia");
            return;
        }

        Optional<ChaveApi> encontrada = chaveApiRepository.findByChaveHash(HashDeChave.sha256Hex(chaveEmClaro));
        Instant agora = Instant.now();

        boolean valida = encontrada.isPresent()
                && encontrada.get().isAtiva()
                && ChaveApi.ESCOPO_INGESTAO.equals(encontrada.get().getEscopo())
                && (encontrada.get().getExpiraEm() == null || encontrada.get().getExpiraEm().isAfter(agora));

        if (!valida) {
            recusar(response, "chave invalida, inativa, expirada ou fora do escopo INGESTAO");
            return;
        }

        // Best-effort: uma falha aqui não pode derrubar a requisição de
        // ingestão, que já foi autenticada com sucesso.
        try {
            ChaveApi chave = encontrada.get();
            chave.marcarUso(agora);
            chaveApiRepository.save(chave);
        } catch (RuntimeException ignorada) {
            logger.warn("falha ao atualizar ultimo_uso_em da chave de API", ignorada);
        }

        chain.doFilter(request, response);
    }

    private void recusar(HttpServletResponse response, String detalhe) throws IOException {
        response.setStatus(ErroDeIngestao.STATUS_NAO_AUTORIZADO);
        response.setContentType("application/json;charset=UTF-8");
        objectMapper.writeValue(response.getWriter(), Map.of("erro", "nao_autorizado", "detalhe", detalhe));
    }
}
