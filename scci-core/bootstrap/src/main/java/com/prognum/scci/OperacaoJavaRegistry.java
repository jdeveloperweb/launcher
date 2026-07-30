package com.prognum.scci;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Component;

/**
 * Registro das operações IMPLEMENTADAS EM JAVA PURO no scci-core (sem Pascal). O {@code /interno/executar}
 * consulta aqui primeiro: se a operação existe → roda Java (trilho <b>PURO</b>); senão cai no SDK
 * (trilho <b>HÍBRIDO</b>) ou, no scci-core puro, responde <i>"não migrada"</i>.
 *
 * <p>Migrar uma operação para Java = <b>registrar o handler aqui</b>. As operações abaixo são REAIS
 * (Java de verdade, não programas Pascal fingidos) e servem para demonstrar/validar o trilho puro.</p>
 */
@Component
public class OperacaoJavaRegistry {

    /** Handler de uma operação em Java puro: recebe (programa, método, rawJson) e devolve o corpo da resposta. */
    @FunctionalInterface
    public interface OperacaoJava {
        String executar(String programa, String metodo, String rawJson);
    }

    private final Map<String, OperacaoJava> ops = new ConcurrentHashMap<>();

    public OperacaoJavaRegistry() {
        registrar("ping-java", (p, m, j) -> "{\"success\":true,\"servico\":\"scci-core\",\"trilho\":\"java-puro\","
                + "\"programa\":\"" + p + "\",\"metodo\":\"" + (m == null ? "" : m) + "\",\"java\":\""
                + System.getProperty("java.version") + "\"}");
        registrar("eco", (p, m, j) -> "{\"success\":true,\"por\":\"java-puro\",\"eco\":"
                + (j == null || j.isBlank() ? "null" : j) + "}");
    }

    public final void registrar(String programa, OperacaoJava op) {
        ops.put(programa, op);
    }

    /** Handler da operação, ou {@code null} se ela NÃO está migrada para Java puro. */
    public OperacaoJava buscar(String programa) {
        return programa == null ? null : ops.get(programa);
    }
}
