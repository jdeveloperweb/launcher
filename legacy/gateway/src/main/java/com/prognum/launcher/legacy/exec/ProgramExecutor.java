package com.prognum.launcher.legacy.exec;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.prognum.launcher.legacy.db.LauncherEnvReader;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.zip.Inflater;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Executor de programas (papel do launcher — fpfork/fpexecve do launcher.pas). O gateway
 * NAO contem logica dos programas: monta o ambiente do launcherenv.ini, EXECUTA o binario
 * real (wmenu, wtela, ...) e fala o protocolo de blocos do oserver, devolvendo a resposta.
 *
 * Protocolo (oserver.pas): bloco = magic(1) + len(4, big-endian/htonl) + dados [zlib se _Z].
 * Request = bloco METD ($FA, "Metodo,") + bloco DATA ($FB, params JSON).
 * Resposta = bloco DATA ($FB) ou DATA_Z ($F9, zlib) ou EXCEPT ($FD, erro).
 *
 * Os programas "w" leem/escrevem UM fd bidirecional (InitFD). A JVM nao cria socketpair, entao
 * o transporte e feito por {@link NativeOserverBridge} (JNA): socketpair + posix_spawn do programa
 * no fd 6 — sem Python, sem processo auxiliar.
 */
@Component
public class ProgramExecutor {

    private static final Logger log = LoggerFactory.getLogger(ProgramExecutor.class);

    private static final Set<String> ROTEAMENTO = Set.of(
            "programName", "methodName", "requestMethod", "programa", "metodo");

    // Magics (oserver.pas)
    private static final int DATA_HDR = 0xFB, DATA_HDR_Z = 0xF9, METD_HDR = 0xFA,
            METD_HDR_Z = 0xF7, METD_HDR_K = 0xFC, METD_HDR_K_Z = 0xF8, EXCEPT_HDR = 0xFD;

    private final LauncherEnvReader env;
    private final ObjectMapper mapper;
    private final long timeoutSegundos;
    private final java.util.concurrent.Semaphore limite;
    private final int maxTentativas;
    private final long retryDelayMs;

    public ProgramExecutor(LauncherEnvReader env,
                           ObjectMapper mapper,
                           @Value("${launcher.executor.timeout-segundos:30}") long timeoutSegundos,
                           @Value("${launcher.executor.max-concorrentes:8}") int maxConcorrentes,
                           @Value("${launcher.executor.max-tentativas:3}") int maxTentativas,
                           @Value("${launcher.executor.retry-delay-ms:120}") long retryDelayMs) {
        this.env = env;
        this.mapper = mapper;
        this.timeoutSegundos = timeoutSegundos;
        this.limite = new java.util.concurrent.Semaphore(Math.max(1, maxConcorrentes), true);
        this.maxTentativas = Math.max(1, maxTentativas);
        this.retryDelayMs = Math.max(0, retryDelayMs);
    }

    public record Resultado(boolean erro, String corpo) { }

    public Resultado executar(String ambiente, String programName, String methodName,
                              String requestMethod, String rawJson, String usuario, String ip) {
        if (!nomeValido(programName) || !nomeValido(methodName)) {
            return erro("Programa/metodo invalido.");
        }
        Map<String, String> ambEnv = env.ambienteEnv(ambiente, usuario);
        String bin = resolverBinario(programName, ambEnv.get("PATH"), ambiente);
        if (bin == null) {
            return erro("Programa nao encontrado: " + programName);
        }
        String metodo = capInicial(verbo(requestMethod)) + capInicial(methodName);

        // params do programa: usa o JSON ORIGINAL do front (preserva null/numeros/estrutura),
        // so removendo os campos de roteamento. NAO achatar para String (o "null" do front
        // viraria a string "null" e quebra a query). O programa faz jsonIn.ParseStream.
        byte[] paramsJson;
        try {
            com.fasterxml.jackson.databind.JsonNode node =
                    mapper.readTree(rawJson == null || rawJson.isBlank() ? "{}" : rawJson);
            if (node instanceof com.fasterxml.jackson.databind.node.ObjectNode obj) {
                obj.remove(ROTEAMENTO);
                paramsJson = mapper.writeValueAsBytes(obj);
            } else {
                paramsJson = "{}".getBytes(StandardCharsets.ISO_8859_1);
            }
        } catch (Exception e) {
            paramsJson = "{}".getBytes(StandardCharsets.ISO_8859_1);
        }

        // request = METD ("Metodo,") + DATA (params)
        ByteArrayOutputStream req = new ByteArrayOutputStream();
        try {
            req.write(bloco(METD_HDR, (metodo + ",").getBytes(StandardCharsets.ISO_8859_1)));
            req.write(bloco(DATA_HDR, paramsJson));
        } catch (IOException e) {
            return erro("Falha montando request.");
        }

        // Retry em chamadas idempotentes (GET): o proprio erro legado diz "tente novamente
        // mais tarde". Em POST/PUT NAO repete (evita escrita dupla).
        boolean idempotente = (requestMethod == null) || requestMethod.trim().equalsIgnoreCase("GET");
        int tentativas = idempotente ? maxTentativas : 1;
        Resultado r = null;
        for (int t = 1; t <= tentativas; t++) {
            r = rodar(req.toByteArray(), bin, ambEnv, ambiente, ip, programName, metodo, usuario);
            if (!r.erro()) {
                return r;
            }
            if (t < tentativas && retryDelayMs > 0) {
                try {
                    Thread.sleep(retryDelayMs);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }
        return r;
    }

    /** Executa o programa UMA vez (respeitando o limite de concorrencia). */
    private Resultado rodar(byte[] reqBytes, String bin, Map<String, String> ambEnv, String ambiente,
                            String ip, String programName, String metodo, String usuario) {
        try {
            limite.acquire();   // limita execucoes concorrentes (espelha MAXCONN do launcher)
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
            return erro("Execucao interrompida.");
        }
        try {
            // env do launcherenv.ini (limpo, so o ambiente do launcher) + PATH minimo.
            Map<String, String> progEnv = new LinkedHashMap<>(ambEnv);
            progEnv.putIfAbsent("PATH", "/usr/bin:/bin");
            String home = ambEnv.get("HOME");
            File dir = (home != null && new File(home).isDirectory()) ? new File(home) : new File(ambiente);
            String cwd = dir.isDirectory() ? dir.getAbsolutePath() : null;

            long ini = System.nanoTime();
            byte[] out = NativeOserverBridge.exchange(bin, progEnv, cwd, ip, reqBytes, timeoutSegundos);
            long ms = (System.nanoTime() - ini) / 1_000_000;

            Resultado r = parseBlocos(out);
            if (r.erro()) {
                String msg = r.corpo() == null ? "" : (r.corpo().length() > 400 ? r.corpo().substring(0, 400) : r.corpo());
                log.warn("program_exec_erro", kv("programa", programName), kv("metodo", metodo),
                        kv("usuario", usuario), kv("mensagem", msg), kv("ms", ms));
            } else {
                log.info("program_exec", kv("programa", programName), kv("metodo", metodo),
                        kv("erro", false), kv("bytes", out.length), kv("ms", ms));
            }
            return r;
        } catch (Exception e) {
            log.warn("program_exec_falha", kv("programa", programName), kv("erro", String.valueOf(e.getMessage())));
            return erro("Falha ao executar " + programName + ": " + e.getMessage());
        } finally {
            limite.release();
        }
    }

    private static byte[] bloco(int magic, byte[] data) {
        byte[] b = new byte[5 + data.length];
        b[0] = (byte) magic;
        b[1] = (byte) (data.length >>> 24);
        b[2] = (byte) (data.length >>> 16);
        b[3] = (byte) (data.length >>> 8);
        b[4] = (byte) data.length;
        System.arraycopy(data, 0, b, 5, data.length);
        return b;
    }

    /** Le os blocos da resposta (magic + len[4 big-endian] + dados; descomprime zlib). */
    private Resultado parseBlocos(byte[] out) {
        if (out.length == 0) {
            return new Resultado(true, "{\"success\":\"false\",\"mensagem\":\"Sem resposta do programa.\"}");
        }
        ByteBuffer bb = ByteBuffer.wrap(out);   // big-endian por padrao
        StringBuilder corpo = new StringBuilder();
        boolean erro = false;
        while (bb.remaining() >= 5) {
            int magic = bb.get() & 0xFF;
            int len = bb.getInt();
            if (len < 0 || len > bb.remaining()) {
                break;
            }
            byte[] data = new byte[len];
            bb.get(data);
            boolean z = (magic == DATA_HDR_Z || magic == METD_HDR_Z || magic == METD_HDR_K_Z);
            byte[] real = z ? inflar(data) : data;
            if (magic == EXCEPT_HDR) {
                erro = true;
            }
            if (magic == DATA_HDR || magic == DATA_HDR_Z || magic == EXCEPT_HDR) {
                corpo.append(new String(real, StandardCharsets.ISO_8859_1));
            }
            if (magic == EXCEPT_HDR) {
                break;
            }
        }
        return new Resultado(erro, corpo.toString());
    }

    private static byte[] inflar(byte[] comp) {
        try {
            Inflater inf = new Inflater();
            inf.setInput(comp);
            ByteArrayOutputStream bos = new ByteArrayOutputStream(comp.length * 3);
            byte[] buf = new byte[4096];
            while (!inf.finished()) {
                int n = inf.inflate(buf);
                if (n == 0) {
                    break;
                }
                bos.write(buf, 0, n);
            }
            inf.end();
            return bos.toByteArray();
        } catch (Exception e) {
            return comp;
        }
    }

    private static String resolverBinario(String programName, String path, String ambiente) {
        List<String> dirs = new ArrayList<>();
        if (path != null) {
            for (String d : path.split(":")) {
                if (!d.isBlank()) {
                    dirs.add(d);
                }
            }
        }
        dirs.add(ambiente + "/binfpc");
        dirs.add("/u/scci/binfpc");
        for (String d : dirs) {
            File f = new File(d, programName);
            if (f.isFile() && f.canExecute()) {
                return f.getAbsolutePath();
            }
        }
        return null;
    }

    private static boolean nomeValido(String s) {
        return s != null && s.matches("[A-Za-z][A-Za-z0-9_]*");
    }

    private static String verbo(String requestMethod) {
        return (requestMethod == null || requestMethod.isBlank()) ? "GET" : requestMethod.trim().toLowerCase();
    }

    private static String capInicial(String s) {
        if (s == null || s.isEmpty()) {
            return s == null ? "" : s;
        }
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }

    private static Resultado erro(String msg) {
        return new Resultado(true, "{\"success\":\"false\",\"mensagem\":\"" + msg.replace("\"", "'") + "\"}");
    }
}
