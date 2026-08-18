package com.prognum.gateway.execucao.pascal;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;
import com.prognum.gateway.execucao.port.out.ExecutorPrograma;

/**
 * Adapter de saída da EXECUÇÃO de programas — cliente HTTP do contrato {@code POST /interno/executar}.
 * Manda o {@link ComandoExecucao} (binário em base64) e reconstrói o {@link ResultadoExecucao}.
 *
 * <p>Reutilizável nos TRÊS trilhos do Strangler (só muda a URL base): <b>pascal</b> (executor/launcher),
 * <b>hibrido</b> (scci-core com SDK) e <b>puro</b> (scci-core Java). É instanciado no
 * {@code WiringConfig} — um bean por trilho. Se o destino estiver fora, devolve erro gracioso (sem 500),
 * igual ao contrato de resposta de programa.</p>
 */
public class ClientePascalExecutor implements ExecutorPrograma {

    private static final Logger log = LoggerFactory.getLogger(ClientePascalExecutor.class);

    private final RestClient rest;

    /** Compat: timeout de leitura default (60s) — cobre o cap de execucao do Pascal (30s) + margem. */
    public ClientePascalExecutor(RestClient.Builder builder, String baseUrl) {
        this(builder, baseUrl, 60_000L);
    }

    public ClientePascalExecutor(RestClient.Builder builder, String baseUrl, long readTimeoutMs) {
        // builder GERENCIADO (instrumentado pelo Micrometer) — injeta o traceparent p/ ligar o trace ponta a ponta.
        // READ-TIMEOUT explicito e generoso: operacoes de escrita PESADAS (ex.: woriginacao/OperacaoSalvaSimulacao,
        // ~14s) passavam do default e o gateway devolvia "indisponivel" MESMO tendo salvo no backend (erro falso +
        // risco de duplicata no retry). O legado nao tem isso (socket direto no oserver). Aqui cobrimos o cap do
        // executor (executor.timeout-ms, 30s) + margem. Connect-timeout curto (o destino e local).
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(5));
        factory.setReadTimeout(Duration.ofMillis(Math.max(1_000L, readTimeoutMs)));
        this.rest = builder.baseUrl(baseUrl).requestFactory(factory).build();
    }

    @Override
    public ResultadoExecucao executar(ComandoExecucao c) {
        String corpoB64 = c.corpoBinario() == null ? null
                : Base64.getEncoder().encodeToString(c.corpoBinario());
        ExecutarRequest req = new ExecutarRequest(c.ambiente(), c.programName(), c.methodName(),
                c.requestMethod(), c.rawJson(), c.usuario(), c.ip(), c.streamComTamanho(), corpoB64);
        try {
            ExecutarResponse resp = rest.post().uri("/interno/executar")
                    .body(req).retrieve().body(ExecutarResponse.class);
            if (resp == null) {
                throw new IllegalStateException("resposta vazia");
            }
            String corpo = resp.corpoBase64() == null ? ""
                    : new String(Base64.getDecoder().decode(resp.corpoBase64()), StandardCharsets.ISO_8859_1);
            return new ResultadoExecucao(resp.erro(), corpo);
        } catch (RuntimeException e) {
            log.warn("pascal_executor_indisponivel programa={} metodo={} erro={}",
                    c.programName(), c.methodName(), String.valueOf(e.getMessage()));
            return new ResultadoExecucao(true,
                    "{\"success\":false,\"message\":\"Servico de execucao indisponivel. Tente novamente.\"}");
        }
    }

    /** Espelham os DTOs do ExecutarController do pascal-executor (contrato do REST interno). */
    private record ExecutarRequest(String ambiente, String programName, String methodName,
                                   String requestMethod, String rawJson, String usuario, String ip,
                                   boolean streamComTamanho, String corpoBinarioBase64) {
    }

    private record ExecutarResponse(boolean erro, String corpoBase64) {
    }
}
