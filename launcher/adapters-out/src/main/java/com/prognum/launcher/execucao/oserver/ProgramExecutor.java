package com.prognum.launcher.execucao.oserver;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.launcher.execucao.model.ComandoExecucao;
import com.prognum.launcher.execucao.model.ResultadoExecucao;
import com.prognum.launcher.execucao.port.out.ExecutorPrograma;
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
 * Executor de programas (papel do launcher — fpfork/fpexecve do launcher.pas). Porte FIEL do
 * launcher SCCI (legado). O reator NAO contem logica dos programas: monta o ambiente do launcherenv.ini,
 * EXECUTA o binario real (wmenu, wtela, ...) e fala o protocolo de blocos do oserver.
 *
 * Protocolo (oserver.pas): bloco = magic(1) + len(4, big-endian/htonl) + dados [zlib se _Z].
 * Request = bloco METD ($FA, "Metodo,") + bloco DATA ($FB, params JSON).
 * Resposta = bloco DATA ($FB) ou DATA_Z ($F9, zlib) ou EXCEPT ($FD, erro).
 *
 * Transporte via {@link NativeOserverBridge} (JNA): socketpair + posix_spawn no fd 6.
 */
@Component
public class ProgramExecutor implements ExecutorPrograma {

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

    @Override
    public ResultadoExecucao executar(ComandoExecucao comando) {
        String ambiente = comando.ambiente();
        String programName = comando.programName();
        String methodName = comando.methodName();
        String requestMethod = comando.requestMethod();
        String rawJson = comando.rawJson();
        String usuario = comando.usuario();
        String ip = comando.ip();

        if (!nomeValido(programName) || !nomeValido(methodName)) {
            return erro("Programa/metodo invalido.");
        }
        Map<String, String> ambEnv = env.ambienteEnv(ambiente, usuario);
        String bin = resolverBinario(programName, ambEnv.get("PATH"), ambiente);
        if (bin == null) {
            return erro("Programa nao encontrado: " + programName);
        }
        String metodo = montaMetodo(requestMethod, methodName);

        // params do programa: o launcher real (wcorp.DoRemoteCall, modo padrao sem HUBToken) envia
        // os params como XML raiz <PMEMORY> (Params.saveToStream), NAO como JSON. Assim um campo
        // vazio como "dados":{} vira <dados></dados> (XML valido) e o programa (que trata 'dados'
        // como XML) nao estoura. Convertendo o JSON do front -> XML PMEMORY.
        byte[] paramsXml;
        try {
            com.fasterxml.jackson.databind.JsonNode node =
                    mapper.readTree(rawJson == null || rawJson.isBlank() ? "{}" : rawJson);
            if (node instanceof com.fasterxml.jackson.databind.node.ObjectNode obj) {
                obj.remove(ROTEAMENTO);
                paramsXml = jsonParaPmemoryXml(obj).getBytes(StandardCharsets.ISO_8859_1);
            } else {
                paramsXml = "<PMEMORY></PMEMORY>".getBytes(StandardCharsets.ISO_8859_1);
            }
        } catch (Exception e) {
            paramsXml = "<PMEMORY></PMEMORY>".getBytes(StandardCharsets.ISO_8859_1);
        }

        // Canal DOCUMENTOS (metodos TStream do apilib): eles leem os params com
        // LoadFromStreamWithSize, entao o payload do DATA precisa ser [tamanho(4, little-endian)]
        // + [XML PMEMORY]. No UPLOAD (putDoc) ainda anexa os [bytes do arquivo] depois (fiel ao
        // DoMultiPartRemoteCall: writeAnsiString(Params.Code)+writeBuffer(binario)). No /w normal
        // (TPXML, LoadFromStream) vai o XML cru, sem prefixo.
        byte[] payload;
        if (comando.corpoBinario() != null) {
            payload = concat(comTamanhoLE(paramsXml), comando.corpoBinario());
        } else if (comando.streamComTamanho()) {
            payload = comTamanhoLE(paramsXml);
        } else {
            payload = paramsXml;
        }

        // request = METD ("Metodo,") + DATA (payload dos params)
        ByteArrayOutputStream req = new ByteArrayOutputStream();
        try {
            req.write(bloco(METD_HDR, (metodo + ",").getBytes(StandardCharsets.ISO_8859_1)));
            req.write(bloco(DATA_HDR, payload));
        } catch (IOException e) {
            return erro("Falha montando request.");
        }

        // Retry so em chamadas idempotentes: deriva do metodo FINAL (Get*). Assim um verbo embutido
        // no nome (ex.: "putX" sem requestMethod) NAO repete (evita escrita dupla). Sem corpo binario.
        boolean idempotente = metodo.startsWith("Get") && comando.corpoBinario() == null;
        int tentativas = idempotente ? maxTentativas : 1;
        ResultadoExecucao r = null;
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

    /** Executa o programa UMA vez (respeitando o limite de concorrencia), via ponte JNA. */
    private ResultadoExecucao rodar(byte[] reqBytes, String bin, Map<String, String> ambEnv, String ambiente,
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

            ResultadoExecucao r = parseBlocos(out);
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

    /**
     * Prefixa os dados com o tamanho em 4 bytes little-endian — formato do SaveToStreamWithSize/
     * LoadFromStreamWithSize do Pascal (x86). Espelha o mesmo LE32 que o DocumentoService usa para
     * LER a resposta (metadados [len][xml][binario]); aqui e para ESCREVER o request dos metodos TStream.
     */
    private static byte[] concat(byte[] a, byte[] b) {
        byte[] r = new byte[a.length + b.length];
        System.arraycopy(a, 0, r, 0, a.length);
        System.arraycopy(b, 0, r, a.length, b.length);
        return r;
    }

    static byte[] comTamanhoLE(byte[] data) {   // package-private p/ teste
        byte[] b = new byte[4 + data.length];
        b[0] = (byte) data.length;
        b[1] = (byte) (data.length >>> 8);
        b[2] = (byte) (data.length >>> 16);
        b[3] = (byte) (data.length >>> 24);
        System.arraycopy(data, 0, b, 4, data.length);
        return b;
    }

    static byte[] bloco(int magic, byte[] data) {   // package-private p/ teste
        byte[] b = new byte[5 + data.length];
        b[0] = (byte) magic;
        b[1] = (byte) (data.length >>> 24);
        b[2] = (byte) (data.length >>> 16);
        b[3] = (byte) (data.length >>> 8);
        b[4] = (byte) data.length;
        System.arraycopy(data, 0, b, 5, data.length);
        return b;
    }

    // ---- JSON -> XML raiz <PMEMORY> (igual ao Params.saveToStream do wcorp, modo padrao) ----
    static String jsonParaPmemoryXml(com.fasterxml.jackson.databind.node.ObjectNode root) {   // package-private p/ teste
        StringBuilder sb = new StringBuilder("<PMEMORY>");
        anexaFilhos(sb, root);
        return sb.append("</PMEMORY>").toString();
    }

    private static void anexaFilhos(StringBuilder sb, com.fasterxml.jackson.databind.JsonNode obj) {
        java.util.Iterator<java.util.Map.Entry<String, com.fasterxml.jackson.databind.JsonNode>> it = obj.fields();
        while (it.hasNext()) {
            java.util.Map.Entry<String, com.fasterxml.jackson.databind.JsonNode> e = it.next();
            String tag = tagValida(e.getKey());
            if (tag == null) {
                continue;   // ignora chave vazia/invalida (ex.: o "":null que o front manda)
            }
            anexaElemento(sb, tag, e.getValue());
        }
    }

    private static void anexaElemento(StringBuilder sb, String tag, com.fasterxml.jackson.databind.JsonNode v) {
        if (v.isObject()) {
            sb.append('<').append(tag).append('>');
            anexaFilhos(sb, v);
            sb.append("</").append(tag).append('>');
        } else if (v.isArray()) {
            for (com.fasterxml.jackson.databind.JsonNode item : v) {   // array -> elemento repetido
                sb.append('<').append(tag).append('>');
                if (item.isObject()) {
                    anexaFilhos(sb, item);
                } else if (!item.isNull()) {
                    sb.append(xmlEscape(item.asText()));
                }
                sb.append("</").append(tag).append('>');
            }
        } else if (v.isNull()) {
            sb.append('<').append(tag).append("></").append(tag).append('>');
        } else {
            sb.append('<').append(tag).append('>').append(xmlEscape(v.asText())).append("</").append(tag).append('>');
        }
    }

    /** Nome de tag XML valido (letra/_ inicial; alfanumerico/._- depois). Senao null (ignora). */
    private static String tagValida(String k) {
        if (k == null || k.isEmpty()) {
            return null;
        }
        char c0 = k.charAt(0);
        if (!Character.isLetter(c0) && c0 != '_') {
            return null;
        }
        for (int i = 1; i < k.length(); i++) {
            char c = k.charAt(i);
            if (!Character.isLetterOrDigit(c) && c != '_' && c != '.' && c != '-') {
                return null;
            }
        }
        return k;
    }

    private static String xmlEscape(String s) {
        if (s == null || s.isEmpty()) {
            return "";
        }
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }

    /** Escapa uma string para caber num valor JSON (aspas, barra, quebras e controles). */
    private static String escaparJson(String s) {
        if (s == null || s.isEmpty()) {
            return "";
        }
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        sb.append(' ');   // outros controles viram espaco
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.toString();
    }

    /**
     * Le a resposta e relaya o PRIMEIRO bloco de resposta — FIEL ao oserver_recebe do launcher
     * (que le UM bloco e repassa). Se o programa escreve o DATA (a resposta) e DEPOIS estoura uma
     * excecao (bloco EXCEPT pos-resposta), o launcher real relaya so o DATA; concatenar os dois
     * corromperia o JSON no front (era o bug de "a tela nao atualiza"). METD/DEBUG sao ignorados.
     */
    static ResultadoExecucao parseBlocos(byte[] out) {   // package-private + static p/ teste
        if (out.length == 0) {
            return new ResultadoExecucao(true, "{\"success\":\"false\",\"mensagem\":\"Sem resposta do programa.\"}");
        }
        ByteBuffer bb = ByteBuffer.wrap(out);   // big-endian por padrao
        while (bb.remaining() >= 5) {
            int magic = bb.get() & 0xFF;
            int len = bb.getInt();
            if (len < 0 || len > bb.remaining()) {
                break;
            }
            byte[] data = new byte[len];
            bb.get(data);
            if (magic == DATA_HDR || magic == DATA_HDR_Z) {           // a resposta -> relaya e para
                byte[] real = (magic == DATA_HDR_Z) ? inflar(data) : data;
                return new ResultadoExecucao(false, new String(real, StandardCharsets.ISO_8859_1));
            }
            if (magic == EXCEPT_HDR) {   // erro/mensagem do programa
                // Fiel ao wcorp.pas (on E:Exception): embrulha a mensagem em
                // {"success":false,"message":"..."}. Se devolvessemos o texto cru, o Ext.decode do
                // front quebraria (nao e JSON) e o modal/tela nao abriria.
                String msg = new String(data, StandardCharsets.ISO_8859_1);
                return new ResultadoExecucao(true, "{\"success\":false,\"message\":\"" + escaparJson(msg) + "\"}");
            }
            // METD ($FA/_Z/_K) e DEBUG ($FE): ignora e continua ate o bloco de resposta
        }
        return new ResultadoExecucao(true, "{\"success\":\"false\",\"mensagem\":\"Resposta invalida do programa.\"}");
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

    private static final Set<String> VERBOS_HTTP = Set.of("GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS");

    /**
     * Monta o nome do metodo do jeito FIEL ao sccidoc.pas/wcorp (main): (1) capitaliza a 1a letra do
     * methodName (MethodName[1] := UpCase); (2) prefixa o verbo com so a 1a maiuscula (Get/Post/Put/...)
     * SOMENTE se requestMethod for um verbo HTTP reconhecido. Se o front ja embute o verbo no nome
     * (ex.: "putDocumentoOperacaoOCR") e NAO manda requestMethod, NAO prefixa -> "PutDocumentoOperacaoOCR".
     * (O bug anterior prefixava "GET" sempre -> "GETDocumentoOperacao"/"GetPutX", rotina nao encontrada.)
     */
    static String montaMetodo(String requestMethod, String methodName) {   // package-private p/ teste
        String m = capInicial(methodName);
        String rm = requestMethod == null ? "" : requestMethod.trim().toUpperCase();
        if (VERBOS_HTTP.contains(rm)) {
            m = capInicial(rm.toLowerCase()) + m;
        }
        return m;
    }

    private static String capInicial(String s) {
        if (s == null || s.isEmpty()) {
            return s == null ? "" : s;
        }
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }

    private static ResultadoExecucao erro(String msg) {
        return new ResultadoExecucao(true, "{\"success\":\"false\",\"mensagem\":\"" + msg.replace("\"", "'") + "\"}");
    }
}
