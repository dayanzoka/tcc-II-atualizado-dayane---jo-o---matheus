package br.edu.purrbytes.telemetria;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Back-end de telemetria do Purr Bytes.
 *
 * <p>Atende aos Eixos 5 (conformidade com a LGPD), 6 (implementacao e integracao)
 * e 7 (testes de desempenho e seguranca) do planejamento do TCC II.
 */
@SpringBootApplication
public class TelemetriaApplication {

    public static void main(String[] args) {
        SpringApplication.run(TelemetriaApplication.class, args);
    }
}
