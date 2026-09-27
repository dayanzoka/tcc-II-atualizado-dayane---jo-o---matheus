package br.edu.purrbytes.telemetria.seguranca;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * SHA-256 hex da chave de API em claro — o mesmo algoritmo que o
 * {@code HashingContext} do Godot usa do outro lado (ver ADR do cliente sobre
 * "não implemente hash à mão"; aqui vale o espelho: não reinvente, use
 * {@code MessageDigest}). A chave em claro nunca é persistida, só comparada.
 */
public final class HashDeChave {

    private HashDeChave() {
    }

    public static String sha256Hex(String texto) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(texto.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(bytes);
        } catch (NoSuchAlgorithmException e) {
            // SHA-256 é garantido pela JVM (JEP 329 / padrão desde sempre); se isto
            // disparar, o ambiente Java está quebrado, não há tratamento sensato.
            throw new IllegalStateException("SHA-256 indisponivel na JVM", e);
        }
    }
}
