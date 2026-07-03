package com.prognum.launcher.autenticacao.rest;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.prognum.launcher.autenticacao.model.ResultadoLogin;
import com.prognum.launcher.autenticacao.model.ResultadoTroca;
import com.prognum.launcher.autenticacao.model.Sessao;
import com.prognum.launcher.autenticacao.port.in.SessaoUseCase;
import com.prognum.launcher.autenticacao.port.out.AcessoJavaPort;
import com.prognum.common.crypto.WcopCrypto;
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
import java.util.Optional;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Adapter de entrada do dominio AUTENTICACAO — reproduz FIEL os handlers /w/login e /w/password do
 * AejsWebController do launcher SCCI (legado) (contrato W_COP: AES no request, XOR/ISO-8859-1 na
 * resposta). So orquestra: decifra -> use case -> cifra. Zero regra aqui.
 */
@RestController
public class AutenticacaoController {

    private static final Logger log = LoggerFactory.getLogger(AutenticacaoController.class);

    /** Resultado padrão quando o scci-core/acesso está indisponível (sem fallback local — o edge só orquestra). */
    private static final ResultadoLogin ACESSO_INDISPONIVEL =
            new ResultadoLogin(false, ' ', null, "Servico de acesso indisponivel. Tente novamente.", null);

    private final ObjectMapper mapper;
    private final WcopCrypto crypto;
    private final AcessoJavaPort acesso;
    private final SessaoUseCase sessoes;
    private final String contexto;
    private final int maxLoginsSimultaneos;

    public AutenticacaoController(ObjectMapper mapper, WcopCrypto crypto, AcessoJavaPort acesso,
                                  SessaoUseCase sessoes,
                                  @Value("${launcher.legacy.wcop.contexto:CORP_WEB}") String contexto,
                                  @Value("${launcher.auth.max-logins-simultaneos:0}") int maxLoginsSimultaneos) {
        this.mapper = mapper;
        this.crypto = crypto;
        this.acesso = acesso;
        this.sessoes = sessoes;
        this.contexto = contexto;
        this.maxLoginsSimultaneos = maxLoginsSimultaneos;   // 0 = ilimitado (QtMaxLogin do launcher)
    }

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

        ResultadoLogin r;
        try {
            r = acesso.login(usuario, senha, ambiente, req.getRemoteAddr()).orElse(ACESSO_INDISPONIVEL);
        } catch (RuntimeException e) {
            log.warn("web_login_erro", kv("usuario", usuario), kv("ambiente", ambiente),
                    kv("erro", String.valueOf(e.getMessage())));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Falha ao validar o login.\"}");
        }

        // QtMaxLogin (launcher): limite de acessos simultaneos por usuario (0 = ilimitado).
        if (r.sucesso() && maxLoginsSimultaneos > 0
                && sessoes.contarSessoesAtivas(usuario, ambiente) >= maxLoginsSimultaneos) {
            log.info("web_login_max_sessoes", kv("usuario", usuario), kv("limite", maxLoginsSimultaneos));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Numero maximo de acessos simultaneos atingido.\",\"codigo\":\"E005\"}");
        }

        String respJson;
        if (r.sucesso()) {
            // clientes payload-mapeado corrigem a grafia (login case-insensitive): a sessão e o USER
            // injetado usam a grafia real da base; o front recebe o userName corrigido de volta.
            String usuarioSessao = r.usuarioEfetivo() != null ? r.usuarioEfetivo() : usuario;
            sessoes.registrar(r.sessionKey(), usuarioSessao, ambiente, req.getRemoteAddr());
            StringBuilder ok = new StringBuilder("{\"success\":\"true\",\"sessionKey\":\"")
                    .append(r.sessionKey()).append("\",\"contexto\":\"").append(contexto).append("\"");
            if (r.usuarioEfetivo() != null) {
                ok.append(",\"userName\":\"").append(escapar(usuarioSessao)).append("\"");
            }
            respJson = ok.append("}").toString();
            log.info("web_login", kv("usuario", usuarioSessao), kv("ambiente", ambiente),
                    kv("codErro", String.valueOf(r.codErro())), kv("cifrado", cifrado));
        } else {
            respJson = jsonFalhaLogin(r.codErro(), r.mensagem());
            log.info("web_login_negado", kv("usuario", usuario), kv("ambiente", ambiente),
                    kv("codErro", String.valueOf(r.codErro())));
        }
        return resposta(cifrado, respJson);
    }

    // ---------------------------------------------------------------- TROCA DE SENHA
    @PostMapping("/w/password")
    public ResponseEntity<byte[]> password(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        String json = cifrado ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));
        Map<String, String> in = camposDoJson(json);

        String sessionKey = primeiro(in, "sessionKey");
        Optional<Sessao> s = sessoes.consultar(sessionKey);
        String usuario = s.map(Sessao::usuario).orElse(primeiro(in, "userName", "usuario", "user", "login"));
        String ambiente = s.map(Sessao::ambienteOperacional)
                .orElse(primeiro(in, "ambienteOperacional", "ambiente"));
        String senhaAtual = primeiro(in, "senhaAtual", "senhaatual", "senha", "password", "currentPassword", "oldPassword");
        String novaSenha = primeiro(in, "novaSenha", "novasenha", "newPassword", "senhaNova", "newpassword", "password2");

        // loga so as CHAVES (nunca os valores das senhas)
        log.info("w_password", kv("usuario", usuario), kv("ambiente", ambiente),
                kv("campos", String.join(",", in.keySet())));

        ResultadoTroca r;
        try {
            r = acesso.trocarSenha(usuario, senhaAtual, novaSenha, ambiente)
                    .orElse(new ResultadoTroca(false, "Servico de acesso indisponivel. Tente novamente."));
        } catch (RuntimeException e) {
            log.warn("web_passwd_erro", kv("usuario", usuario), kv("erro", String.valueOf(e.getMessage())));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Falha ao trocar a senha.\"}");
        }
        String respJson = r.sucesso()
                ? "{\"success\":\"true\",\"message\":\"" + escapar(r.mensagem()) + "\"}"
                : "{\"success\":false,\"message\":\"" + escapar(r.mensagem()) + "\"}";
        return resposta(cifrado, respJson);
    }

    // ---------------------------------------------------------------- ESQUECI A SENHA
    // /w/email-pwd = ExecutaEmailPwd do loginbd: gera senha temporaria e envia por e-mail.
    @PostMapping("/w/email-pwd")
    public ResponseEntity<byte[]> emailPwd(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        String json = cifrado ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));
        Map<String, String> in = camposDoJson(json);

        String usuario = primeiro(in, "userName", "usuario", "user", "login");
        String cpf = primeiro(in, "userCPF", "cpf", "userCpf");
        String ambiente = primeiro(in, "ambienteOperacional", "ambiente");
        log.info("w_email_pwd", kv("usuario", usuario), kv("ambiente", ambiente));

        ResultadoTroca r;
        try {
            r = acesso.recuperar(usuario, cpf, ambiente)
                    .orElse(new ResultadoTroca(false, "Servico de acesso indisponivel. Tente novamente."));
        } catch (RuntimeException e) {
            log.warn("web_email_pwd_erro", kv("usuario", usuario), kv("erro", String.valueOf(e.getMessage())));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Falha ao recuperar a senha.\"}");
        }
        String respJson = r.sucesso()
                ? "{\"success\":\"true\",\"message\":\"" + escapar(r.mensagem()) + "\"}"
                : "{\"success\":false,\"message\":\"" + escapar(r.mensagem()) + "\"}";
        return resposta(cifrado, respJson);
    }

    // ---------------------------------------------------------------- VALIDA CPF / PROTOCOLO
    // /w/valida-acesso = ValidaCpf/ValidaProtocolo do loginbd (building block do login-por-CPF).
    @PostMapping("/w/valida-acesso")
    public ResponseEntity<byte[]> validaAcesso(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        String json = cifrado ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));
        Map<String, String> in = camposDoJson(json);
        String tipo = primeiro(in, "tipo", "formatoLogin");
        String valor = primeiro(in, "valor", "cpf", "protocolo", "login");
        String ambiente = primeiro(in, "ambienteOperacional", "ambiente");

        boolean valido;
        try {
            valido = "protocolo".equalsIgnoreCase(tipo)
                    ? acesso.validarProtocolo(valor, ambiente).orElse(false)
                    : acesso.validarCpf(valor, ambiente).orElse(false);
        } catch (RuntimeException e) {
            log.warn("web_valida_acesso_erro", kv("tipo", tipo), kv("erro", String.valueOf(e.getMessage())));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Falha ao validar o acesso.\"}");
        }
        return resposta(cifrado, "{\"success\":\"true\",\"valido\":" + valido + "}");
    }

    // ---------------------------------------------------------------- LOGOUT
    @PostMapping("/w/logout")
    public ResponseEntity<byte[]> logout(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        String json = cifrado ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));
        String sessionKey = primeiro(camposDoJson(json), "sessionKey");
        sessoes.encerrar(sessionKey);   // apaga da SCCI_SESSION + Redis
        log.info("web_logout", kv("sessaoEncerrada", sessionKey != null));
        return resposta(cifrado, "{\"success\":\"true\"}");
    }

    // -------------------------------------------------------------- helpers (iguais ao legado)
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

    /**
     * Login NEGADO no contrato do front (wcorp.pas: success BOOLEANO false + 'message' + 'codigo').
     * E004 = troca obrigatoria / senha expirada; E003 = captcha.
     */
    private String jsonFalhaLogin(char codErro, String mensagem) {
        String codigo = switch (codErro) {
            case 'M', 'E' -> "E004";
            case 'K' -> "E003";
            default -> null;
        };
        StringBuilder sb = new StringBuilder("{\"success\":false,\"message\":\"");
        sb.append(escapar(mensagem)).append("\"");
        if (codigo != null) {
            sb.append(",\"codigo\":\"").append(codigo).append("\"");
        }
        return sb.append("}").toString();
    }

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

    private static String escapar(String s) {
        return s == null ? "" : s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
