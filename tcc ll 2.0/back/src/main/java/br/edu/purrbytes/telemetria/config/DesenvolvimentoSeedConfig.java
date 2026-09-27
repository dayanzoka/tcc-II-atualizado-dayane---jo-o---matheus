package br.edu.purrbytes.telemetria.config;

import br.edu.purrbytes.telemetria.seguranca.ChaveApiRepository;
import br.edu.purrbytes.telemetria.seguranca.HashDeChave;
import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Só roda com {@code --spring.profiles.active=dev} (o mesmo perfil que já
 * embute um pepper de desenvolvimento em application-dev.yml). Sem uma rota
 * de administração ainda, não há como emitir uma chave de API de outro jeito;
 * isto existe para o time conseguir testar as rotas de ingestão de ponta a
 * ponta com o cliente Godot antes dessa rota existir.
 *
 * <p>A chave em claro só existe aqui (impressa uma vez no log de boot) e no
 * config.cfg de quem for testar — nunca no banco, que só guarda o hash,
 * exatamente como qualquer outra chave de produção.
 */
@Configuration
@Profile("dev")
public class DesenvolvimentoSeedConfig {

    private static final Logger log = LoggerFactory.getLogger(DesenvolvimentoSeedConfig.class);

    // Chave de desenvolvimento, obviamente marcada como tal -- NAO usar em
    // coleta real (mesma politica de application-dev.yml para o pepper).
    private static final String CHAVE_DEV_EM_CLARO = "pb_ingestao_dev_nao_usar_em_coleta_real";
    private static final String PREFIXO_DEV = "pb_ingest";

    @Bean
    public CommandLineRunner semearChaveApiDeDesenvolvimento(
            ChaveApiRepository chaveApiRepository, JdbcTemplate jdbcTemplate) {
        return args -> {
            if (chaveApiRepository.existsByPrefixo(PREFIXO_DEV)) {
                return;
            }
            String hash = HashDeChave.sha256Hex(CHAVE_DEV_EM_CLARO);
            jdbcTemplate.update(
                    "insert into operacao.chave_api (id_chave, nome, prefixo, chave_hash, escopo, ativa, criada_em) "
                            + "values (?, ?, ?, ?, 'INGESTAO', true, ?)",
                    UUID.randomUUID(), "chave de desenvolvimento (cliente Godot local)", PREFIXO_DEV, hash, Instant.now());
            log.info("chave de API de DESENVOLVIMENTO semeada. Use no config.cfg do jogo: {}", CHAVE_DEV_EM_CLARO);
        };
    }
}
