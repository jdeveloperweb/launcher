package com.prognum.launcher.autenticacao.rest;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.prognum.launcher.autenticacao.model.ResultadoLogin;
import com.prognum.launcher.autenticacao.model.ResultadoTroca;
import com.prognum.launcher.autenticacao.model.Sessao;
import com.prognum.launcher.autenticacao.port.in.SessaoUseCase;
import com.prognum.launcher.autenticacao.port.out.AcessoJavaPort;
import com.prognum.launcher.autenticacao.port.out.RegistroEventoAcesso;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.crypto.LogAnonimizador;
import com.prognum.common.crypto.WcopCrypto;
import io.swagger.v3.oas.annotations.tags.Tag;
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
@Tag(name = "Autenticacao", description = "Login, troca de senha, validação de CPF/protocolo e logout. "
        + "Sem MFA/CAPTCHA/recuperação por e-mail (fora do escopo — ver DECISOES-TECNICAS.md).")
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
    // QtMaxLogin do launcher legado: capacidade HERDADA, desligada por padrao (0 = ilimitado).
    // Doc Final de Requisitos (Gestao de Sessoes / Escopo Negativo): "limitacao de sessoes por
    // usuario" esta fora do escopo ATIVO desta entrega -- o parametro fica documentado aqui como
    // herdado do legado, nao como feature nova; nao ligar sem decisao de negocio explicita.
    private final int maxLoginsSimultaneos;
    // Doc Final de Requisitos (2.9.3): fora do modo dev, a requisicao deve ser cifrada (W_COP).
    // Default FALSE preserva o comportamento atual (smoke-test.sh e deploys hoje mandam JSON puro,
    // sem profile de ambiente formalizado) -- ligar via launcher.wcop.exigir-cifrado=true exige
    // decisao operacional coordenada com o front antes do rollout.
    private final boolean exigirCifrado;
    // Log de eventos de acesso (secao [LOG] do launcherenv, ex.: sccilog) — best-effort/assincrono.
    private final RegistroEventoAcesso eventos;
    // Leitura do launcherenv.ini por-ambiente (ex.: ACESSOSSIMULTANEOS).
    private final LauncherEnvReader env;

    public AutenticacaoController(ObjectMapper mapper, WcopCrypto crypto, AcessoJavaPort acesso,
                                  SessaoUseCase sessoes, RegistroEventoAcesso eventos, LauncherEnvReader env,
                                  @Value("${launcher.legacy.wcop.contexto:CORP_WEB}") String contexto,
                                  @Value("${launcher.auth.max-logins-simultaneos:0}") int maxLoginsSimultaneos,
                                  @Value("${launcher.wcop.exigir-cifrado:false}") boolean exigirCifrado) {
        this.mapper = mapper;
        this.crypto = crypto;
        this.acesso = acesso;
        this.sessoes = sessoes;
        this.eventos = eventos;
        this.env = env;
        this.contexto = contexto;
        this.maxLoginsSimultaneos = maxLoginsSimultaneos;   // 0 = ilimitado (QtMaxLogin do launcher)
        this.exigirCifrado = exigirCifrado;
    }

    /** Doc Final de Requisitos (2.9.3): rejeita corpo nao-cifrado quando exigirCifrado=true. */
    private ResponseEntity<byte[]> rejeicaoSeNaoCifrado(boolean cifrado, byte[] body) {
        if (exigirCifrado && !cifrado && body != null && body.length > 0) {
            log.info("wcop_nao_cifrado_rejeitado");
            return resposta(false,
                    "{\"success\":false,\"message\":\"Requisicao deve ser cifrada (W_COP).\",\"codigo\":\"E006\"}");
        }
        return null;
    }

    // ---------------------------------------------------------------- LOGIN
    @PostMapping("/w/login")
    public ResponseEntity<byte[]> login(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        ResponseEntity<byte[]> rejeicao = rejeicaoSeNaoCifrado(cifrado, body);
        if (rejeicao != null) {
            return rejeicao;
        }

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
            log.warn("web_login_erro", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                    kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())), kv("ambiente", ambiente),
                    kv("erro", String.valueOf(e.getMessage())));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Falha ao validar o login.\"}");
        }

        // Limite de acessos simultaneos por usuario: ACESSOSSIMULTANEOS do launcherenv (POR-AMBIENTE);
        // sem a chave -> cai no global (launcher.auth.max-logins-simultaneos, 0 = ilimitado).
        int limiteSessoes = env.acessosSimultaneos(ambiente);
        if (limiteSessoes <= 0) {
            limiteSessoes = maxLoginsSimultaneos;
        }
        if (r.sucesso() && limiteSessoes > 0
                && sessoes.contarSessoesAtivas(usuario, ambiente) >= limiteSessoes) {
            log.info("web_login_max_sessoes", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                    kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())), kv("limite", limiteSessoes));
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
            log.info("web_login", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuarioSessao)),
                    kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())), kv("ambiente", ambiente),
                    kv("sessaoId", LogAnonimizador.pseudonimizarSessao(r.sessionKey())),
                    kv("codErro", String.valueOf(r.codErro())), kv("cifrado", cifrado));
            eventos.registrar(ambiente, "login", usuarioSessao, req.getRemoteAddr(), contexto, r.sessionKey());
        } else {
            respJson = jsonFalhaLogin(r.codErro(), r.mensagem());
            log.info("web_login_negado", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                    kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())), kv("ambiente", ambiente),
                    kv("codErro", String.valueOf(r.codErro())));
            eventos.registrar(ambiente, "loginerr", usuario, req.getRemoteAddr(), contexto, null);
        }
        return resposta(cifrado, respJson);
    }

    // ---------------------------------------------------------------- TROCA DE SENHA
    @PostMapping("/w/password")
    public ResponseEntity<byte[]> password(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        ResponseEntity<byte[]> rejeicao = rejeicaoSeNaoCifrado(cifrado, body);
        if (rejeicao != null) {
            return rejeicao;
        }
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
        log.info("w_password", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())), kv("ambiente", ambiente),
                kv("sessaoId", LogAnonimizador.pseudonimizarSessao(sessionKey)),
                kv("campos", String.join(",", in.keySet())));

        ResultadoTroca r;
        try {
            r = acesso.trocarSenha(usuario, senhaAtual, novaSenha, ambiente)
                    .orElse(new ResultadoTroca(false, "Servico de acesso indisponivel. Tente novamente."));
        } catch (RuntimeException e) {
            log.warn("web_passwd_erro", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                    kv("erro", String.valueOf(e.getMessage())));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Falha ao trocar a senha.\"}");
        }
        if (r.sucesso()) {
            eventos.registrar(ambiente, "passwd", usuario, req.getRemoteAddr(), contexto, null);
        }
        String respJson = r.sucesso()
                ? "{\"success\":\"true\",\"message\":\"" + escapar(r.mensagem()) + "\"}"
                : "{\"success\":false,\"message\":\"" + escapar(r.mensagem()) + "\"}";
        return resposta(cifrado, respJson);
    }

    // -------------------------------------------------- ESQUECI MINHA SENHA (recuperação por e-mail)
    // Porte do ExecutaEmailPwd do loginbd.pas: gera senha temporária, grava forçando troca e envia por e-mail.
    @PostMapping("/w/email-pwd")
    public ResponseEntity<byte[]> emailPwd(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        ResponseEntity<byte[]> rejeicao = rejeicaoSeNaoCifrado(cifrado, body);
        if (rejeicao != null) {
            return rejeicao;
        }
        String json = cifrado ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));
        Map<String, String> in = camposDoJson(json);
        String usuario = primeiro(in, "userName", "usuario", "user", "login");
        String cpf = primeiro(in, "cpf", "CPF", "documento");
        String ambiente = primeiro(in, "ambienteOperacional", "ambiente");

        ResultadoTroca r;
        try {
            r = acesso.recuperar(usuario, cpf, ambiente)
                    .orElse(new ResultadoTroca(false, "Servico de acesso indisponivel. Tente novamente."));
        } catch (RuntimeException e) {
            log.warn("web_email_pwd_erro", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                    kv("erro", String.valueOf(e.getMessage())));
            return resposta(cifrado, "{\"success\":false,\"message\":\"Falha ao recuperar a senha.\"}");
        }
        log.info("web_email_pwd", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())), kv("ambiente", ambiente),
                kv("sucesso", r.sucesso()));
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
        ResponseEntity<byte[]> rejeicao = rejeicaoSeNaoCifrado(cifrado, body);
        if (rejeicao != null) {
            return rejeicao;
        }
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
    // legado: o front (ExtJS, o MESMO do /aejs Pascal) chama "w/logoff" ao clicar em Sair.
    // "logout" era nome proprio meu -> dava 404 e a SAIDA nunca registrava. Aceita ambos por seguranca.
    @PostMapping({"/w/logoff", "/w/logout"})
    public ResponseEntity<byte[]> logout(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        ResponseEntity<byte[]> rejeicao = rejeicaoSeNaoCifrado(cifrado, body);
        if (rejeicao != null) {
            return rejeicao;
        }
        String json = cifrado ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));
        String sessionKey = primeiro(camposDoJson(json), "sessionKey");
        Optional<Sessao> s = sessoes.consultar(sessionKey);   // captura usuario/ambiente ANTES de encerrar (p/ o log de evento)
        sessoes.encerrar(sessionKey);   // apaga da SCCI_SESSION + Redis
        log.info("web_logout", kv("sessaoEncerrada", sessionKey != null),
                kv("sessaoId", LogAnonimizador.pseudonimizarSessao(sessionKey)),
                kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())));
        s.ifPresent(ses -> eventos.registrar(ses.ambienteOperacional(), "logout", ses.usuario(),
                req.getRemoteAddr(), contexto, sessionKey));
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
     * E004 = troca obrigatoria / senha expirada.
     * (Doc Final de Requisitos: E003/captcha removido — fora do escopo inicial.)
     */
    private String jsonFalhaLogin(char codErro, String mensagem) {
        String codigo = switch (codErro) {
            case 'M', 'E' -> "E004";
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
