package com.prognum.launcher.execucao.rest;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.prognum.launcher.autenticacao.model.Sessao;
import com.prognum.launcher.autenticacao.port.in.SessaoUseCase;
import com.prognum.common.crypto.WcopCrypto;
import com.prognum.launcher.execucao.model.ComandoExecucao;
import com.prognum.launcher.execucao.model.ResultadoExecucao;
import com.prognum.launcher.execucao.port.in.DespachoUseCase;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Adapter de entrada do dominio EXECUCAO — reproduz FIEL o despacho /w do AejsWebController do
 * launcher SCCI (legado). O launcher recebe /w, VALIDA a sessao e EXECUTA o programa real (wmenu/wtela).
 * NENHUMA logica de programa aqui — so orquestracao (decifra -> valida sessao -> executa -> cifra).
 */
@RestController
public class DespachoController {

    private static final Logger log = LoggerFactory.getLogger(DespachoController.class);

    private final ObjectMapper mapper;
    private final WcopCrypto crypto;
    private final SessaoUseCase sessoes;
    private final DespachoUseCase despacho;

    public DespachoController(ObjectMapper mapper, WcopCrypto crypto,
                              SessaoUseCase sessoes, DespachoUseCase despacho) {
        this.mapper = mapper;
        this.crypto = crypto;
        this.sessoes = sessoes;
        this.despacho = despacho;
    }

    @PostMapping("/w")
    public ResponseEntity<byte[]> dispatch(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        String json = cifrado ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));

        Map<String, String> in = camposDoJson(json);
        String programName = primeiro(in, "programName", "programa");
        String methodName = primeiro(in, "methodName", "metodo");
        String requestMethod = primeiro(in, "requestMethod");

        // VALIDA (papel do launcher): revalida o token ANTES de executar o programa.
        String sessionKey = primeiro(in, "sessionKey");
        String usuarioParam = primeiro(in, "userName", "usuario");
        String ambienteParam = primeiro(in, "ambienteOperacional", "ambiente");
        Optional<Sessao> s = sessoes.validar(sessionKey, usuarioParam, ambienteParam);

        // Se veio sessionKey mas a sessao NAO e valida -> rejeita (nao executa). Sem sessionKey
        // (chamada de dev/curl), segue com os parametros (facilita teste local).
        if (sessionKey != null && s.isEmpty()) {
            log.info("w_dispatch_sessao_invalida", kv("sessionKey", sessionKey), kv("usuario", usuarioParam));
            return resposta(cifrado,
                    "{\"success\":false,\"message\":\"Sessao expirada. Faca login novamente.\",\"codigo\":\"E004\"}");
        }
        String usuario = s.map(Sessao::usuario).orElse(usuarioParam);
        String ambiente = s.map(Sessao::ambienteOperacional).orElse(ambienteParam);

        String paramsDbg = in.toString();
        if (paramsDbg.length() > 600) {
            paramsDbg = paramsDbg.substring(0, 600);
        }
        log.info("w_dispatch", kv("programName", programName), kv("methodName", methodName),
                kv("requestMethod", requestMethod), kv("usuario", usuario), kv("sessaoValida", s.isPresent()),
                kv("params", paramsDbg));

        ResultadoExecucao r = despacho.despachar(new ComandoExecucao(
                ambiente, programName, methodName, requestMethod, json, usuario, req.getRemoteAddr()));
        return resposta(cifrado, r.corpo());
    }

    private ResponseEntity<byte[]> resposta(boolean cifrado, String json) {
        if (cifrado) {
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, "application/json; charset=ISO-8859-1")
                    .body(crypto.cifraResposta(json));
        }
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, "application/json; charset=UTF-8")
                .body(json.getBytes(StandardCharsets.UTF_8));
    }

    private Map<String, String> camposDoJson(String json) {
        Map<String, String> m = new LinkedHashMap<>();
        try {
            JsonNode node = mapper.readTree(json);
            if (node != null && node.isObject()) {
                node.fields().forEachRemaining(e -> m.put(e.getKey(), e.getValue().asText()));
            }
        } catch (Exception ignore) {
            // corpo nao-JSON
        }
        return m;
    }

    private static String primeiro(Map<String, String> m, String... chaves) {
        for (String k : chaves) {
            String v = m.get(k);
            if (v != null && !v.isBlank()) {
                return v;
            }
        }
        return null;
    }
}
