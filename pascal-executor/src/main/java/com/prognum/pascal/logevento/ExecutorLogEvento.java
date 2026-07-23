package com.prognum.pascal.logevento;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.prognum.common.environment.LauncherEnvReader;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Log de eventos de acesso (login/logout/erro/troca) — executa o programa configurado na secao
 * {@code [LOG]} do launcherenv.ini (ex.: {@code sccilog -z LOGON $USER}), FIEL ao ExecLog do
 * launcher.pas. Vive no pascal-executor porque e ele que tem os binarios + o {@code ambiente/} + a
 * expansao de {@code $USER}. Config-driven: sem {@code [LOG]} para o evento -> nao faz nada.
 *
 * <p>O proprio {@code sccilog} ja grava o evento, atualiza {@code DT_ULTIMO_ACESSO} (no login) e
 * elimina a sessao (no logout) — nao reimplementamos nada, so EXECUTAMOS o binario.</p>
 */
@Component
public class ExecutorLogEvento {

    private static final Logger log = LoggerFactory.getLogger(ExecutorLogEvento.class);

    /** evento (do launcher) -> chave da secao [LOG] do launcherenv.ini. */
    private static final Map<String, String> CHAVE = Map.of(
            "login", "LOGIN", "logout", "LOGOFF", "loginerr", "LOGINERR", "passwd", "LOGPASSWD");

    private final LauncherEnvReader env;
    private final long timeoutSegundos;

    public ExecutorLogEvento(LauncherEnvReader env,
                             @Value("${logevento.timeout-segundos:10}") long timeoutSegundos) {
        this.env = env;
        this.timeoutSegundos = timeoutSegundos;
    }

    /**
     * Monta o argv do comando [LOG] (PURO, testavel): expande {@code $USER} no template e anexa
     * {@code <ip> <origem> [session_key]} — a ordem que o sccilog espera
     * ({@code sccilog -z EVENTO USER IP ORIGEM [SESSION]}). Lista VAZIA = sem [LOG] p/ o evento.
     */
    static List<String> montarComando(Map<String, String> secaoLog, Map<String, String> ambienteEnv,
                                      String evento, String ip, String origem, String sessionKey) {
        String chave = CHAVE.get(evento == null ? "" : evento.toLowerCase());
        if (chave == null) {
            return List.of();
        }
        String cmd = secaoLog.get(chave);
        if (cmd == null || cmd.isBlank()) {
            return List.of();
        }
        String expandido = LauncherEnvReader.expandirVariaveis(cmd, ambienteEnv);
        List<String> argv = new ArrayList<>();
        for (String tok : expandido.trim().split("\\s+")) {
            if (!tok.isEmpty()) {
                argv.add(tok);
            }
        }
        argv.add(ip == null ? "" : ip);
        argv.add(origem == null ? "" : origem);
        if (sessionKey != null && !sessionKey.isBlank()) {
            argv.add(sessionKey);
        }
        return argv;
    }

    /** Best-effort: executa o programa [LOG] do ambiente para o evento. NUNCA lanca (nao pode quebrar o login). */
    public void registrar(String ambiente, String evento, String usuario, String ip, String origem, String sessionKey) {
        try {
            Map<String, String> secaoLog = env.logEventos(ambiente);
            if (secaoLog.isEmpty()) {
                return;   // cliente sem [LOG] -> sem log de evento
            }
            Map<String, String> ambienteEnv = env.ambienteEnv(ambiente, usuario);
            List<String> argv = montarComando(secaoLog, ambienteEnv, evento, ip, origem, sessionKey);
            if (argv.isEmpty()) {
                return;
            }
            // resolve o executavel pelo PATH do AMBIENTE (igual ao SetAmbiente do launcher.pas): o
            // ProcessBuilder do Java procura o binario no PATH da JVM, NAO no que passamos em
            // environment() — sem isto o "sccilog" (que fica no binfpc do SCCI) nunca e achado.
            argv.set(0, resolverExecutavel(argv.get(0), ambienteEnv));

            ProcessBuilder pb = new ProcessBuilder(argv);
            pb.environment().putAll(ambienteEnv);   // ORACLE_HOME/SCCIDIR*/PATH do ambiente p/ o sccilog rodar
            pb.redirectErrorStream(true);
            Process p = pb.start();
            boolean terminou = p.waitFor(timeoutSegundos, TimeUnit.SECONDS);
            if (!terminou) {
                p.destroyForcibly();
            }
            log.info("log_evento", kv("evento", evento), kv("ambiente", ambiente),
                    kv("ok", terminou), kv("exit", terminou ? p.exitValue() : -1));
        } catch (Exception e) {
            if (programaIndisponivel(e)) {
                // esperado em ambiente sem o binario legado (ex.: sccilog nao instalado): NAO e falha
                // de verdade — a auditoria ja foi garantida no log do launcher (evento_acesso).
                log.info("log_evento_programa_indisponivel", kv("evento", evento), kv("ambiente", ambiente),
                        kv("detalhe", "programa da secao [LOG] nao encontrado no ambiente"));
            } else {
                log.warn("log_evento_falha", kv("evento", evento), kv("ambiente", ambiente),
                        kv("erro", String.valueOf(e.getMessage())));
            }
        }
    }

    /**
     * Resolve o executavel (argv[0]) para caminho ABSOLUTO usando o PATH do AMBIENTE (launcherenv.ini),
     * exatamente como o SetAmbiente do launcher.pas: procura o binario nos diretorios do PATH do env
     * (ex.: {@code /u/scci/binfpc}) e devolve o caminho completo. Necessario porque o
     * {@link ProcessBuilder} resolve o comando pelo PATH da JVM (que nao tem o binfpc do SCCI), e nao
     * pelo PATH que passamos em {@link ProcessBuilder#environment()}. Se ja vier com {@code '/'} (caminho
     * explicito) ou nao for achado no PATH, devolve o comando inalterado (a execucao entao falha e cai
     * no "programa indisponivel"). O separador e sempre {@code ':'} (launcherenv e config de Linux).
     */
    static String resolverExecutavel(String comando, Map<String, String> ambienteEnv) {
        if (comando == null || comando.contains("/")) {
            return comando;   // ja tem caminho -> nao mexe (fiel: so resolve nome "solto")
        }
        String path = ambienteEnv == null ? null : ambienteEnv.get("PATH");
        if (path == null || path.isBlank()) {
            return comando;
        }
        for (String dir : path.split(":")) {
            if (dir.isBlank()) {
                continue;
            }
            java.io.File f = new java.io.File(dir, comando);
            if (f.isFile() && f.canExecute()) {
                return f.getAbsolutePath();
            }
        }
        return comando;   // nao achou no PATH do ambiente -> deixa falhar (indisponivel)
    }

    /**
     * O programa [LOG] nao existe/nao e executavel? ({@link ProcessBuilder#start()} lanca
     * {@code IOException "Cannot run program ...: error=2, No such file or directory"}). Caso esperado
     * quando o cliente nao tem o binario legado — nao deve poluir o log com WARN a cada acesso.
     */
    static boolean programaIndisponivel(Throwable e) {
        if (!(e instanceof java.io.IOException)) {
            return false;
        }
        String m = e.getMessage() == null ? "" : e.getMessage().toLowerCase();
        return m.contains("cannot run program") || m.contains("no such file") || m.contains("error=2");
    }
}
