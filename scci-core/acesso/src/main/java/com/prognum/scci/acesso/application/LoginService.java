package com.prognum.scci.acesso.application;

import com.prognum.common.crypto.LogAnonimizador;
import com.prognum.scci.acesso.domain.model.ResultadoLogin;
import com.prognum.scci.acesso.domain.port.in.LoginUseCase;
import com.prognum.scci.acesso.domain.port.out.Autenticador;
import com.prognum.scci.acesso.domain.port.out.ContadorTentativas;
import com.prognum.scci.acesso.domain.port.out.MetodoLoginResolver;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.security.SecureRandom;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * COORDENADOR do login. Concentra o que é COMUM a todos os clientes/mecanismos — bloqueio por
 * tentativas, atraso anti-brute-force, emissão de sessionKey, log — e delega a VERIFICAÇÃO
 * da credencial ao {@link Autenticador} (Strategy) do cliente, escolhido pelo {@link MetodoLoginResolver}
 * (config por cliente). Assim cada loginXXX.pas vira uma Strategy fiel e portar um cliente novo do
 * mesmo tipo é só configuração. POJO puro.
 *
 * <p><b>Doc Final de Requisitos (Autenticação):</b> CAPTCHA e MFA estão fora do escopo inicial —
 * removidos deste coordenador. O único mecanismo anti-brute-force é o bloqueio por excesso de
 * tentativas (código 'X'), que permanece.</p>
 */
public class LoginService implements LoginUseCase {

    private static final Logger log = LoggerFactory.getLogger(LoginService.class);
    private static final char[] ALFABETO = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".toCharArray();

    private final Map<String, Autenticador> porMetodo = new LinkedHashMap<>();
    private final MetodoLoginResolver resolver;
    private final ContadorTentativas attempts;
    private final SecureRandom rnd = new SecureRandom();

    private final long delayMs;
    private final int maxErros;

    public LoginService(List<Autenticador> autenticadores, MetodoLoginResolver resolver,
                        ContadorTentativas attempts, long delayMs, int maxErros) {
        for (Autenticador a : autenticadores) {
            porMetodo.put(a.metodo().toUpperCase(), a);
        }
        this.resolver = resolver;
        this.attempts = attempts;
        this.delayMs = delayMs;
        this.maxErros = maxErros;
    }

    @Override
    public ResultadoLogin login(String usuarioRaw, String senha, String ambiente, String ip) {
        String usuario = usuarioRaw == null ? "" : usuarioRaw.trim();

        if (attempts.get(usuario) > maxErros) {
            return new ResultadoLogin(false, 'X', null, "Usuario bloqueado por excesso de tentativas.", null);
        }

        Autenticador autenticador = autenticadorDe(ambiente);
        ResultadoLogin r = autenticador.autenticar(usuario, senha, ambiente, ip);
        char cod = r.codErro();

        // credencial inválida (F/B) -> conta tentativa + escala bloqueio (comum a todos)
        if (cod == 'F' || cod == 'B') {
            int n = attempts.registerFailure(usuario);
            delay();
            if (n > maxErros) {
                return new ResultadoLogin(false, 'X', null, "Usuario bloqueado por excesso de tentativas.", null);
            }
            return r;
        }

        // credencial válida -> zera tentativas
        attempts.reset(usuario);

        if (r.sucesso()) {   // 'T' (ok) ou 'C' (aviso) -> emite a sessão (papel do coordenador)
            // a Strategy PODE já ter emitido o token (payload-mapeado gera o mesmo do INSERT); senão gera aqui
            String token = r.sessionKey() != null ? r.sessionKey() : novaSessionKey();
            log.info("wcop_login_ok", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                    kv("ip", LogAnonimizador.mascararIp(ip)), kv("ambiente", ambiente),
                    kv("metodo", autenticador.metodo()), kv("codErro", String.valueOf(cod)));
            return new ResultadoLogin(true, cod, token, r.mensagem(), r.diasRestantes(), r.usuarioEfetivo());
        }
        // 'E' (expirada) / 'M' (troca obrigatória): autenticou, mas o estado bloqueia — sem sessão
        return r;
    }

    /** Escolhe a Strategy pela config do cliente; default e fallback = BANCO (loginbd). */
    private Autenticador autenticadorDe(String ambiente) {
        String metodo = resolver.metodoDe(ambiente);
        Autenticador a = metodo == null ? null : porMetodo.get(metodo.toUpperCase());
        if (a == null) {
            a = porMetodo.get(AutenticadorBanco.METODO);
        }
        if (a == null) {
            throw new IllegalStateException("nenhum autenticador BANCO configurado");
        }
        return a;
    }

    private String novaSessionKey() {
        StringBuilder sb = new StringBuilder(29);
        for (int i = 0; i < 29; i++) {
            sb.append(ALFABETO[rnd.nextInt(ALFABETO.length)]);
        }
        return sb.toString();
    }

    private void delay() {
        if (delayMs > 0) {
            try {
                Thread.sleep(delayMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }
}
