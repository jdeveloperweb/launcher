package com.prognum.launcher.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.prognum.launcher.legacy.crypto.WcopCrypto;
import com.prognum.launcher.legacy.exec.ProgramExecutor;
import com.prognum.launcher.legacy.login.WcopLoginService;
import com.prognum.launcher.legacy.login.WcopPasswordService;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Compatibilidade com o front /aejs-l (copia de teste do /aejs) — nativo e ISOLADO,
 * sem tocar no /aejs real.
 *
 *  - POST /w/login     -> decifra (AES W_COP), valida na base real do ambiente
 *                         (loginbd.pas), devolve {success, sessionKey, contexto} cifrado (XOR).
 *  - GET  /w/wmenu/menu -> menu (ainda fixo).
 */
@RestController
public class AejsWebController {

    private static final Logger log = LoggerFactory.getLogger(AejsWebController.class);

    private final ObjectMapper mapper;
    private final WcopCrypto crypto;
    private final WcopLoginService loginService;
    private final ProgramExecutor executor;
    private final WcopPasswordService passwordService;
    private final String contexto;

    /** Sessoes emitidas aqui (isolado): sessionKey -> dados. */
    private final Map<String, Sessao> sessoes = new ConcurrentHashMap<>();

    public AejsWebController(ObjectMapper mapper,
                             WcopCrypto crypto,
                             WcopLoginService loginService,
                             ProgramExecutor executor,
                             WcopPasswordService passwordService,
                             @Value("${launcher.legacy.wcop.contexto:CORP_WEB}") String contexto) {
        this.mapper = mapper;
        this.crypto = crypto;
        this.loginService = loginService;
        this.executor = executor;
        this.passwordService = passwordService;
        this.contexto = contexto;
    }

    private record Sessao(String usuario, String ambienteOperacional) { }

    // ---------------------------------------------------------------- LOGIN
    @PostMapping("/w/login")
    public ResponseEntity<byte[]> login(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);

        String json = cifrado
                ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));

        Map<String, String> in = camposDoJson(json);
        req.getParameterMap().forEach((k, v) -> {           // dev: aceita query/form tambem
            if (v != null && v.length > 0) {
                in.putIfAbsent(k, v[0]);
            }
        });

        String usuario = primeiro(in, "userName", "usuario", "user", "login");
        String senha = primeiro(in, "password", "senha");
        String ambiente = primeiro(in, "ambienteOperacional", "ambiente");

        WcopLoginService.Resultado r;
        try {
            r = loginService.login(usuario, senha, ambiente, req.getRemoteAddr());
        } catch (RuntimeException e) {
            log.warn("web_login_erro", kv("usuario", usuario), kv("ambiente", ambiente),
                    kv("erro", String.valueOf(e.getMessage())));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Falha ao validar o login.\"}");
        }

        String respJson;
        if (r.sucesso()) {
            sessoes.put(r.sessionKey(), new Sessao(usuario, ambiente));
            respJson = "{\"success\":\"true\",\"sessionKey\":\"" + r.sessionKey()
                    + "\",\"contexto\":\"" + contexto + "\"}";
            log.info("web_login", kv("usuario", usuario), kv("ambiente", ambiente),
                    kv("codErro", String.valueOf(r.codErro())), kv("cifrado", cifrado));
        } else {
            // Contrato do front (ExtJS faz `if(a.success)`): falha = success BOOLEANO false
            // + campo `message` (nao `mensagem`); string "false" seria truthy -> falso "logou".
            respJson = jsonFalhaLogin(r.codErro(), r.mensagem());
            log.info("web_login_negado", kv("usuario", usuario), kv("ambiente", ambiente),
                    kv("codErro", String.valueOf(r.codErro())));
        }
        return resposta(cifrado, respJson);
    }

    // ---------------------------------------------------------------- TROCA DE SENHA
    // /w/password = operacao PASSWD do loginbd (familia login) -> WcopPasswordService (banco real).
    @PostMapping("/w/password")
    public ResponseEntity<byte[]> password(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        String json = cifrado ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));
        Map<String, String> in = camposDoJson(json);

        String sessionKey = primeiro(in, "sessionKey");
        Sessao s = sessionKey == null ? null : sessoes.get(sessionKey);
        String usuario = (s != null) ? s.usuario() : primeiro(in, "userName", "usuario", "user", "login");
        String ambiente = (s != null) ? s.ambienteOperacional() : primeiro(in, "ambienteOperacional", "ambiente");
        String senhaAtual = primeiro(in, "senhaAtual", "senhaatual", "senha", "password", "currentPassword", "oldPassword");
        String novaSenha = primeiro(in, "novaSenha", "novasenha", "newPassword", "senhaNova", "newpassword", "password2");

        // loga so as CHAVES (nunca os valores das senhas)
        log.info("w_password", kv("usuario", usuario), kv("ambiente", ambiente),
                kv("campos", String.join(",", in.keySet())));

        WcopPasswordService.Resultado r;
        try {
            r = passwordService.trocar(usuario, senhaAtual, novaSenha, ambiente);
        } catch (RuntimeException e) {
            log.warn("web_passwd_erro", kv("usuario", usuario), kv("erro", String.valueOf(e.getMessage())));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Falha ao trocar a senha.\"}");
        }
        // Mesmo contrato do login: sucesso = "true" (string truthy), falha = false (booleano), campo `message`.
        String respJson = r.sucesso()
                ? "{\"success\":\"true\",\"message\":\"" + escapar(r.mensagem()) + "\"}"
                : "{\"success\":false,\"message\":\"" + escapar(r.mensagem()) + "\"}";
        return resposta(cifrado, respJson);
    }

    /** Resposta no formato do front: cifrada (XOR) se a requisicao veio cifrada; senao JSON puro. */
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

    // -------------------------------------------------- DESPACHANTE /w (CRIPTOGRAFA)
    // O launcher recebe /w, valida a sessao e EXECUTA o programa real (wmenu/wtela/...).
    // NENHUMA logica de programa aqui — so orquestracao.
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

        // Sessao: o launcher valida o token antes de executar o programa.
        String sessionKey = primeiro(in, "sessionKey");
        Sessao s = sessionKey == null ? null : sessoes.get(sessionKey);
        String usuario = (s != null) ? s.usuario() : primeiro(in, "userName", "usuario");
        String ambiente = (s != null) ? s.ambienteOperacional() : primeiro(in, "ambienteOperacional", "ambiente");

        String paramsDbg = in.toString();
        if (paramsDbg.length() > 600) {
            paramsDbg = paramsDbg.substring(0, 600);
        }
        log.info("w_dispatch", kv("programName", programName), kv("methodName", methodName),
                kv("requestMethod", requestMethod), kv("usuario", usuario), kv("sessaoValida", s != null),
                kv("params", paramsDbg));

        ProgramExecutor.Resultado r = executor.executar(
                ambiente, programName, methodName, requestMethod, json, usuario, req.getRemoteAddr());
        return resposta(cifrado, r.corpo());
    }

    // -------------------------------------------------------------- helpers
    private Map<String, String> camposDoJson(String json) {
        Map<String, String> m = new LinkedHashMap<>();
        try {
            JsonNode node = mapper.readTree(json);
            if (node != null && node.isObject()) {
                node.fields().forEachRemaining(e -> m.put(e.getKey(), e.getValue().asText()));
            }
        } catch (Exception ignore) {
            // corpo nao-JSON: campos virao dos parameters
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

    /**
     * Resposta de login NEGADO no contrato do front (wcorp.pas: p.addChild('success').AsBoolean := false
     * + 'message' + 'codigo'). E004 = troca obrigatoria / senha expirada; E003 = captcha.
     */
    private String jsonFalhaLogin(char codErro, String mensagem) {
        String codigo = switch (codErro) {
            case 'M', 'E' -> "E004";   // troca obrigatoria / expirada -> front abre a troca de senha
            case 'K' -> "E003";        // captcha obrigatorio
            default -> null;
        };
        StringBuilder sb = new StringBuilder("{\"success\":false,\"message\":\"");
        sb.append(escapar(mensagem)).append("\"");
        if (codigo != null) {
            sb.append(",\"codigo\":\"").append(codigo).append("\"");
        }
        return sb.append("}").toString();
    }

    private static String escapar(String s) {
        return s == null ? "" : s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
