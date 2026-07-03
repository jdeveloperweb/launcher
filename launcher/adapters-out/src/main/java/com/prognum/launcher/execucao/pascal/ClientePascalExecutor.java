package com.prognum.launcher.execucao.pascal;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import com.prognum.launcher.execucao.model.ComandoExecucao;
import com.prognum.launcher.execucao.model.ResultadoExecucao;
import com.prognum.launcher.execucao.port.out.ExecutorPrograma;

/**
 * Cliente do REST interno do <b>pascal-executor</b> — o caminho REMOTO da execução de programas Pascal.
 * Manda o {@link ComandoExecucao} (binário em base64) para {@code POST /interno/executar} e reconstrói o
 * {@link ResultadoExecucao}. Falha de transporte propaga (o {@code RoteadorExecutor} decide o fallback).
 *
 * Assim o launcher (edge) NÃO precisa de JNA/nativo: a ponte oserver (socketpair + posix_spawn + fd 6)
 * vive só no pascal-executor, co-localizado com os binários Pascal.
 */
@Component
public class ClientePascalExecutor implements ExecutorPrograma {

    private final RestClient rest;

    public ClientePascalExecutor(
            @Value("${launcher.pascal-executor.url:http://localhost:8091}") String baseUrl) {
        this.rest = RestClient.builder().baseUrl(baseUrl).build();
    }

    @Override
    public ResultadoExecucao executar(ComandoExecucao c) {
        String corpoB64 = c.corpoBinario() == null ? null
                : Base64.getEncoder().encodeToString(c.corpoBinario());
        ExecutarRequest req = new ExecutarRequest(c.ambiente(), c.programName(), c.methodName(),
                c.requestMethod(), c.rawJson(), c.usuario(), c.ip(), c.streamComTamanho(), corpoB64);
        ExecutarResponse resp = rest.post().uri("/interno/executar")
                .body(req).retrieve().body(ExecutarResponse.class);
        if (resp == null) {
            throw new IllegalStateException("pascal-executor devolveu resposta vazia");
        }
        String corpo = resp.corpoBase64() == null ? ""
                : new String(Base64.getDecoder().decode(resp.corpoBase64()), StandardCharsets.ISO_8859_1);
        return new ResultadoExecucao(resp.erro(), corpo);
    }

    /** Espelham os DTOs do ExecutarController do pascal-executor (contrato do REST interno). */
    private record ExecutarRequest(String ambiente, String programName, String methodName,
                                   String requestMethod, String rawJson, String usuario, String ip,
                                   boolean streamComTamanho, String corpoBinarioBase64) {
    }

    private record ExecutarResponse(boolean erro, String corpoBase64) {
    }
}
