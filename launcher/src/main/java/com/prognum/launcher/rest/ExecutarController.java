package com.prognum.launcher.rest;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.launcher.model.ComandoExecucao;
import com.prognum.launcher.model.ResultadoExecucao;
import com.prognum.launcher.port.ExecutorPrograma;

/**
 * REST INTERNO do pascal-executor: executa um programa "w" e devolve o bloco de resposta cru. O
 * launcher (edge) chama quando a flag {@code executor.remoto} aponta REMOTO. NÃO exposto ao front.
 *
 * Binários ({@code corpoBinario} de upload; {@code corpo} da resposta — que carrega bytes em
 * ISO-8859-1) trafegam em <b>base64</b> no JSON, lossless (evita problema de UTF-8).
 */
@RestController
public class ExecutarController {

    private final ExecutorPrograma executor;

    public ExecutarController(ExecutorPrograma executor) {
        this.executor = executor;
    }

    @PostMapping("/interno/executar")
    public ResponseEntity<ExecutarResponse> executar(@RequestBody ExecutarRequest req) {
        byte[] corpoBin = req.corpoBinarioBase64() == null ? null
                : Base64.getDecoder().decode(req.corpoBinarioBase64());
        ComandoExecucao cmd = new ComandoExecucao(req.ambiente(), req.programName(), req.methodName(),
                req.requestMethod(), req.rawJson(), req.usuario(), req.ip(), req.streamComTamanho(), corpoBin);
        ResultadoExecucao r = executor.executar(cmd);
        String corpoB64 = r.corpo() == null ? null
                : Base64.getEncoder().encodeToString(r.corpo().getBytes(StandardCharsets.ISO_8859_1));
        return ResponseEntity.ok(new ExecutarResponse(r.erro(), corpoB64));
    }

    /** Corpo do request: os campos do ComandoExecucao (corpoBinario em base64, nulo se não houver). */
    public record ExecutarRequest(String ambiente, String programName, String methodName,
                                  String requestMethod, String rawJson, String usuario, String ip,
                                  boolean streamComTamanho, String corpoBinarioBase64) {
    }

    /** Resposta: erro (bloco EXCEPT) + corpo cru em base64 (ISO-8859-1). */
    public record ExecutarResponse(boolean erro, String corpoBase64) {
    }
}
