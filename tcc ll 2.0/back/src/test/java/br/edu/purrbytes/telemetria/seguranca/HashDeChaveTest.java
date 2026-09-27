package br.edu.purrbytes.telemetria.seguranca;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class HashDeChaveTest {

    @Test
    void vetorConhecidoDeAbc() {
        // Vetor oficial do SHA-256, o mesmo que HashingContext usa no cliente Godot.
        assertThat(HashDeChave.sha256Hex("abc"))
                .isEqualTo("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    }

    @Test
    void vetorConhecidoDeStringVazia() {
        assertThat(HashDeChave.sha256Hex(""))
                .isEqualTo("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85");
    }

    @Test
    void chavesDiferentesProduzemHashesDiferentes() {
        assertThat(HashDeChave.sha256Hex("chave-a")).isNotEqualTo(HashDeChave.sha256Hex("chave-b"));
    }
}
