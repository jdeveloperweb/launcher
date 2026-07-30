package com.prognum.scci;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.launcher.model.ComandoExecucao;
import com.prognum.launcher.model.ResultadoExecucao;
import com.prognum.launcher.port.ExecutorPrograma;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Endpoint UNIFICADO da execução no scci-core ({@code POST /interno/executar}) — o MESMO contrato do
 * serviço launcher, mas resolvendo os DOIS últimos trilhos do Strangler in-process:
 *
 * <ol>
 *   <li><b>PURO</b> — se a operação está no {@link OperacaoJavaRegistry}, roda Java puro (sem Pascal);</li>
 *   <li><b>HÍBRIDO</b> — senão, se o SDK está presente ({@code scci.sdk.habilitado=true}), roda o Pascal
 *       in-process via o {@code launcher-sdk} embutido;</li>
 *   <li>senão (scci-core PURO, sem SDK) — responde <i>"operação não migrada"</i> (falha graciosa).</li>
 * </ol>
 *
 * <p>Assim o MESMO artefato serve o deploy <b>puro</b> (só o passo 1/3) e o <b>híbrido</b> (1→2). Quem
 * decide qual instância recebe cada operação é o gateway (feature-flag por programa). Logs explícitos:
 * {@code java_puro} (puro), {@code sdk_hibrido_*} (híbrido) e {@code rota_nao_migrada}.</p>
 */
@RestController
class ExecutarInternoController {

    private static final Logger log = LoggerFactory.getLogger(ExecutarInternoController.class);

    private final OperacaoJavaRegistry registry;
    private final ObjectProvider<ExecutorPrograma> sdk;   // presente só no híbrido (SdkHibridoConfig)

    ExecutarInternoController(OperacaoJavaRegistry registry, ObjectProvider<ExecutorPrograma> sdk) {
        this.registry = registry;
        this.sdk = sdk;
    }

    @PostMapping("/interno/executar")
    public ResponseEntity<ExecutarResponse> executar(@RequestBody ExecutarRequest req) {
        // (1) TRILHO PURO — operação implementada em Java? roda Java, sem Pascal.
        OperacaoJavaRegistry.OperacaoJava op = registry.buscar(req.programName());
        if (op != null) {
            long t0 = System.nanoTime();
            String corpo = op.executar(req.programName(), req.methodName(), req.rawJson());
            long ms = (System.nanoTime() - t0) / 1_000_000;
            log.info("java_puro", kv("modulo", "exec"), kv("operacao", req.programName()),
                    kv("via", "java-puro"), kv("ms", ms));
            return ResponseEntity.ok(new ExecutarResponse(false, b64(corpo)));
        }

        // (2) TRILHO HÍBRIDO — SDK presente? roda o Pascal DIRETO no scci-core, via o launcher-sdk.
        ExecutorPrograma executor = sdk.getIfAvailable();
        if (executor != null) {
            byte[] corpoBin = req.corpoBinarioBase64() == null ? null
                    : Base64.getDecoder().decode(req.corpoBinarioBase64());
            ComandoExecucao cmd = new ComandoExecucao(req.ambiente(), req.programName(), req.methodName(),
                    req.requestMethod(), req.rawJson(), req.usuario(), req.ip(), req.streamComTamanho(), corpoBin);
            log.info("sdk_hibrido_exec", kv("host", "scci-core"), kv("via", "launcher-sdk (in-process)"),
                    kv("programa", req.programName()), kv("metodo", req.methodName()), kv("ambiente", req.ambiente()));
            long t0 = System.nanoTime();
            ResultadoExecucao r = executor.executar(cmd);
            long ms = (System.nanoTime() - t0) / 1_000_000;
            log.info("sdk_hibrido_ok", kv("host", "scci-core"), kv("via", "launcher-sdk"),
                    kv("programa", req.programName()), kv("erro", r.erro()), kv("ms", ms));
            String corpoB64 = r.corpo() == null ? null
                    : Base64.getEncoder().encodeToString(r.corpo().getBytes(StandardCharsets.ISO_8859_1));
            return ResponseEntity.ok(new ExecutarResponse(r.erro(), corpoB64));
        }

        // (3) scci-core PURO sem Java para isto — não há Pascal aqui. Falha graciosa (contrato de programa).
        log.info("rota_nao_migrada", kv("host", "scci-core"), kv("via", "java-puro"), kv("programa", req.programName()));
        return ResponseEntity.ok(new ExecutarResponse(true, b64(
                "{\"success\":false,\"message\":\"Operacao nao migrada para Java puro (indisponivel no scci-core puro).\","
                        + "\"codigo\":\"E-NAO-MIGRADA\"}")));
    }

    private static String b64(String s) {
        return Base64.getEncoder().encodeToString(s.getBytes(StandardCharsets.ISO_8859_1));
    }

    /** MESMO contrato do ExecutarController do launcher (o gateway envia isto). */
    public record ExecutarRequest(String ambiente, String programName, String methodName,
                                  String requestMethod, String rawJson, String usuario, String ip,
                                  boolean streamComTamanho, String corpoBinarioBase64) {
    }

    public record ExecutarResponse(boolean erro, String corpoBase64) {
    }
}
