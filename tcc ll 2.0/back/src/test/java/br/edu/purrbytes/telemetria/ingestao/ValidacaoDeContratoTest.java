package br.edu.purrbytes.telemetria.ingestao;

import static org.assertj.core.api.Assertions.assertThat;

import br.edu.purrbytes.telemetria.ingestao.dto.AbrirSessaoRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.EventoRequest;
import br.edu.purrbytes.telemetria.ingestao.dto.TentativaRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

/**
 * Bean Validation puro, sem contexto Spring nem banco -- roda em milissegundos
 * e cobre exatamente as garantias que docs/contrato-telemetria.md promete ao
 * time do jogo (ex.: "resultado" so aceita o vocabulario fechado).
 */
class ValidacaoDeContratoTest {

    private static ValidatorFactory factory;
    private static Validator validator;

    @BeforeAll
    static void configurar() {
        factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @AfterAll
    static void encerrar() {
        factory.close();
    }

    @Test
    void abrirSessaoValidaNaoGeraViolacao() {
        AbrirSessaoRequest req = new AbrirSessaoRequest(
                UUID.randomUUID(), UUID.randomUUID(), "0.1.0", "Windows", Instant.now());
        assertThat(validator.validate(req)).isEmpty();
    }

    @Test
    void abrirSessaoSemPlataformaFalha() {
        AbrirSessaoRequest req = new AbrirSessaoRequest(
                UUID.randomUUID(), UUID.randomUUID(), "0.1.0", "", Instant.now());
        assertThat(validator.validate(req)).isNotEmpty();
    }

    @Test
    void eventoSemIdFaseFalha() {
        // id_fase e obrigatorio desde a mudanca de contrato de 2026-09-14.
        EventoRequest req = new EventoRequest(UUID.randomUUID(), UUID.randomUUID(), 0,
                "FASE_INICIADA", null, "Cesar", 1, Instant.now(), null);
        Set<ConstraintViolation<EventoRequest>> violacoes = validator.validate(req);
        assertThat(violacoes).anyMatch(v -> v.getPropertyPath().toString().equals("idFase"));
    }

    @Test
    void eventoComFaseForaDeUmAQuatroFalha() {
        EventoRequest req = new EventoRequest(UUID.randomUUID(), UUID.randomUUID(), 0,
                "FASE_INICIADA", UUID.randomUUID(), "Cesar", 7, Instant.now(), null);
        assertThat(validator.validate(req)).isNotEmpty();
    }

    @Test
    void tentativaComResultadoForaDoVocabularioFalha() {
        TentativaRequest req = new TentativaRequest(UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), "Cesar", 1, "cesar-01", "cifrar pacote chave=3", null,
                "QUASE_SUCESSO", null, 100, 1, Instant.now());
        assertThat(validator.validate(req)).isNotEmpty();
    }

    @Test
    void tentativaValidaComResultadoDoVocabularioNaoGeraViolacao() {
        TentativaRequest req = new TentativaRequest(UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), "Cesar", 1, "cesar-01", "cifrar pacote chave=3", null,
                "SUCESSO", null, 100, 1, Instant.now());
        assertThat(validator.validate(req)).isEmpty();
    }
}
