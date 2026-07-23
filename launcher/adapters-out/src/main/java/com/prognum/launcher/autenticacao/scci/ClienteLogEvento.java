package com.prognum.launcher.autenticacao.scci;

import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import com.prognum.common.crypto.LogAnonimizador;
import com.prognum.launcher.autenticacao.port.out.RegistroEventoAcesso;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Registra o log de eventos de acesso (login/logout/loginerr/passwd) em DOIS niveis:
 *
 * <ol>
 *   <li><b>Auditoria GARANTIDA</b> — uma linha estruturada {@code evento_acesso} no proprio log do
 *       launcher, SINCRONA, gravada em todo evento. Nao depende de nenhum binario legado nem do
 *       pascal-executor estar no ar: e a garantia de que entrada e saida SEMPRE ficam registradas
 *       (usuario pseudonimizado / IP mascarado / sessao pseudonimizada — req 2.7).</li>
 *   <li><b>Complemento LEGADO (opcional)</b> — dispara o programa da secao [LOG] do launcherenv.ini
 *       (ex.: {@code sccilog}) via pascal-executor (POST /interno/log-evento). ASSINCRONO e
 *       best-effort: o cliente que tiver o binario ganha o log no banco (DT_ULTIMO_ACESSO, etc.);
 *       quem nao tiver, nao perde a auditoria — ela ja foi feita no passo 1.</li>
 * </ol>
 *
 * <p>Motivacao: em ambientes sem o {@code sccilog} instalado, o passo 2 falhava em silencio e nao
 * havia registro NENHUM de acesso. O passo 1 remove essa dependencia.</p>
 */
@Component
public class ClienteLogEvento implements RegistroEventoAcesso {

    private static final Logger log = LoggerFactory.getLogger(ClienteLogEvento.class);

    private final RestClient rest;
    private final ExecutorService pool = Executors.newFixedThreadPool(2, r -> {
        Thread t = new Thread(r, "log-evento");
        t.setDaemon(true);
        return t;
    });

    public ClienteLogEvento(RestClient.Builder builder,
                            @Value("${launcher.pascal-executor.url:http://localhost:8091}") String baseUrl) {
        // builder GERENCIADO (instrumentado). Obs.: o POST abaixo roda no pool async 'log-evento', FORA
        // do contexto do trace da requisicao — auditoria best-effort, nao entra na cascata do RTT.
        this.rest = builder.baseUrl(baseUrl).build();
    }

    @Override
    public void registrar(String ambiente, String evento, String usuario, String ip, String origem, String sessionKey) {
        // 1) AUDITORIA GARANTIDA (sincrona, sempre grava — nao depende do sccilog nem do pascal-executor)
        log.info("evento_acesso",
                kv("evento", nz(evento)),
                kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                kv("ambiente", nz(ambiente)),
                kv("ip", LogAnonimizador.mascararIp(ip)),
                kv("origem", nz(origem)),
                kv("sessao", sessionKey == null || sessionKey.isBlank() ? "" : LogAnonimizador.pseudonimizarSessao(sessionKey)));

        // 2) COMPLEMENTO LEGADO (assincrono, best-effort): roda o programa [LOG] do cliente, se houver
        pool.execute(() -> {
            try {
                rest.post().uri("/interno/log-evento")
                        .body(Map.of("ambiente", nz(ambiente), "evento", nz(evento), "usuario", nz(usuario),
                                "ip", nz(ip), "origem", nz(origem), "sessionKey", nz(sessionKey)))
                        .retrieve().toBodilessEntity();
            } catch (RuntimeException e) {
                log.warn("log_evento_envio_falha", kv("evento", evento), kv("erro", String.valueOf(e.getMessage())));
            }
        });
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }
}
