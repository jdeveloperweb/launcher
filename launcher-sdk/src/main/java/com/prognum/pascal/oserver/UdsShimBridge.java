package com.prognum.pascal.oserver;

import java.io.File;
import java.io.IOException;
import java.net.StandardProtocolFamily;
import java.net.UnixDomainSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.ServerSocketChannel;
import java.nio.channels.SocketChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.PosixFilePermissions;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

/**
 * Transporte v2 (Alt4 do TDD "tdd-sdk-pascal"): <b>UDS + shim</b>. Java PURO (ServerSocketChannel UNIX,
 * JDK 16+) — sem JNA, sem código nativo no caminho de dados, e o SocketChannel <b>estaciona</b> a virtual
 * thread (zero pinning), diferente do JNA que prende o carrier.
 *
 * <p><b>NÃO toca em nenhum programa Pascal.</b> O {@code shim} (executável à parte, ver src/main/native/shim.c)
 * conecta no UDS, faz {@code dup2} do socket para o <b>FD 6</b> e dá {@code exec} no {@code w} ORIGINAL — que
 * vê o FD 6 idêntico ao socketpair de hoje. Handshake por token (env {@code OSERVER_TOKEN}) garante que quem
 * conectou é o filho esperado; path por chamada + permissão 0600; deadline absoluto por watchdog.</p>
 *
 * <p>Framing igual à v1 (oserver): escreve o request, {@code shutdownOutput()} (= shutdown(WR)) e lê até EOF.
 * Timeout/erro NUNCA retorna resposta parcial (o watchdog fecha o canal → exceção, não EOF).</p>
 */
final class UdsShimBridge {

    private UdsShimBridge() {
    }

    private static final int TOKEN_BYTES = 16;          // 32 chars hex
    private static final SecureRandom RNG = new SecureRandom();
    private static final ScheduledExecutorService WATCHDOG =
            Executors.newSingleThreadScheduledExecutor(r -> {
                Thread t = new Thread(r, "uds-deadline");
                t.setDaemon(true);
                return t;
            });

    /**
     * Executa o programa via UDS+shim. {@code shim} = caminho do executável shim; demais args iguais ao
     * {@link NativeOserverBridge#exchange}. Preenche {@code fasesNanos} ([0]=setup, [1]=roundtrip) se != null.
     */
    static byte[] exchange(String shim, String bin, Map<String, String> env, String cwd, String ip,
                           byte[] request, long timeoutMs, long[] fasesNanos) throws IOException {
        long t0 = System.nanoTime();
        Path sock = Files.createTempFile("oserver-", ".sock");
        Files.delete(sock);   // o bind recria o arquivo; só queríamos um nome único (path curto p/ o limite do UDS)
        String token = hex(randomBytes());

        Process proc = null;
        ScheduledFuture<?> deadline = null;
        try (ServerSocketChannel server = ServerSocketChannel.open(StandardProtocolFamily.UNIX)) {
            server.bind(UnixDomainSocketAddress.of(sock));
            restringe(sock);   // 0600 no socket

            // deadline ABSOLUTO da operação: ao estourar, fecha o server -> qualquer accept/read/write
            // bloqueado aborta com exceção (nunca deixa retornar resposta parcial como sucesso).
            deadline = WATCHDOG.schedule(() -> fecha(server), timeoutMs, TimeUnit.MILLISECONDS);

            // sobe o shim:  shim <uds> <bin> 6 6 <ip>   (env do programa + OSERVER_TOKEN)
            List<String> cmd = new ArrayList<>(List.of(
                    shim, sock.toString(), bin, "6", "6", ip == null ? "127.0.0.1" : ip));
            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.environment().clear();
            pb.environment().putAll(env);
            pb.environment().put("OSERVER_TOKEN", token);
            if (cwd != null) {
                pb.directory(new File(cwd));   // cwd por-filho (sem chdir global — some o problema da v1/JNA)
            }
            proc = pb.start();

            SocketChannel ch = server.accept();   // bloqueante = ESTACIONA a virtual thread; watchdog garante o deadline
            try (ch) {
                // handshake: lê o token que o shim enviou e confere (rejeita conexão impostora)
                byte[] got = leExato(ch, token.length());
                if (got == null || !token.equals(new String(got, StandardCharsets.US_ASCII))) {
                    throw new IOException("handshake do shim invalido (conexao inesperada no UDS)");
                }
                long tSetup = System.nanoTime();

                escreveTudo(ch, ByteBuffer.wrap(request));
                ch.shutdownOutput();           // sinaliza EOF ao programa (= shutdown(WR))

                byte[] resp = leAteEof(ch);    // fim = programa fechou o socket. Timeout -> watchdog fecha -> exceção.
                if (fasesNanos != null && fasesNanos.length >= 2) {
                    fasesNanos[0] = tSetup - t0;                 // setup (bind + spawn + accept + handshake)
                    fasesNanos[1] = System.nanoTime() - tSetup;  // roundtrip (~ tempo de resposta do Pascal)
                }
                return resp;
            }
        } finally {
            if (deadline != null) {
                deadline.cancel(false);
            }
            try {
                Files.deleteIfExists(sock);
            } catch (IOException ignore) {
                // path efêmero; melhor esforço
            }
            colher(proc);
        }
    }

    // ---- helpers ----

    private static byte[] randomBytes() {
        byte[] b = new byte[TOKEN_BYTES];
        RNG.nextBytes(b);
        return b;
    }

    private static String hex(byte[] b) {
        StringBuilder sb = new StringBuilder(b.length * 2);
        for (byte x : b) {
            sb.append(Character.forDigit((x >> 4) & 0xF, 16)).append(Character.forDigit(x & 0xF, 16));
        }
        return sb.toString();
    }

    private static void restringe(Path sock) {
        try {
            Files.setPosixFilePermissions(sock, PosixFilePermissions.fromString("rw-------"));
        } catch (IOException | UnsupportedOperationException ignore) {
            // FS sem POSIX (ex.: dev Windows): o path já é único + o token protege; segue.
        }
    }

    private static void fecha(ServerSocketChannel s) {
        try {
            s.close();
        } catch (IOException ignore) {
            // idempotente
        }
    }

    private static byte[] leExato(SocketChannel ch, int n) throws IOException {
        ByteBuffer buf = ByteBuffer.allocate(n);
        while (buf.hasRemaining()) {
            if (ch.read(buf) < 0) {
                return null;   // EOF antes do token completo
            }
        }
        return buf.array();
    }

    private static void escreveTudo(SocketChannel ch, ByteBuffer buf) throws IOException {
        while (buf.hasRemaining()) {
            if (ch.write(buf) < 0) {
                throw new IOException("falha escrevendo no socket do programa");
            }
        }
    }

    private static byte[] leAteEof(SocketChannel ch) throws IOException {
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream(65536);
        ByteBuffer buf = ByteBuffer.allocate(65536);
        while (true) {
            int n = ch.read(buf);
            if (n < 0) {
                return out.toByteArray();   // EOF = resposta completa
            }
            if (n > 0) {
                out.write(buf.array(), 0, n);
                buf.clear();
            }
        }
    }

    /** Colhe o filho (o shim virou o programa via exec). Só mata se ainda vivo; a JVM reapa o zumbi. */
    private static void colher(Process p) {
        if (p != null && p.isAlive()) {
            p.destroyForcibly();
        }
    }
}
