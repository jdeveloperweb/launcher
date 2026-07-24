package com.prognum.pascal.oserver;

import com.sun.jna.Library;
import com.sun.jna.Memory;
import com.sun.jna.Native;
import com.sun.jna.NativeLong;
import com.sun.jna.Pointer;
import com.sun.jna.StringArray;
import com.sun.jna.ptr.IntByReference;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Map;

/**
 * Ponte NATIVA (JNA) entre o reator e os programas "w" do oserver — copia fiel do legado
 * congelado. Faz o mesmo que o launcher.pas no fpfork/fpexecve:
 *
 *   socketpair(AF_UNIX) -> posix_spawn(programa) com o fd do filho dup2'd para o fd 6
 *   (InitFD le/escreve UM fd bidirecional); o pai escreve o request, da shutdown(WR) e le a resposta.
 *
 * O programa e chamado como `programa 6 6 <ip>`. Nenhuma logica de programa aqui — so o transporte.
 *
 * Por que posix_spawn (e nao fork+exec cru): a JVM e multithread; fork seguido de chamadas
 * nao async-signal-safe trava. posix_spawn e o primitivo seguro. Como o glibc do servidor e 2.28
 * (sem posix_spawn_file_actions_addchdir_np, que so existe em 2.29+), o diretorio de trabalho e
 * ajustado com um chdir SERIALIZADO no pai, restaurado assim que o spawn retorna.
 */
final class NativeOserverBridge {

    private NativeOserverBridge() {
    }

    // ---- constantes do Linux/x86_64 ----
    private static final int AF_UNIX = 1;
    private static final int SOCK_STREAM = 1;
    private static final int F_SETFD = 2;
    private static final int FD_CLOEXEC = 1;
    private static final int SHUT_WR = 1;
    private static final int SOL_SOCKET = 1;
    private static final int SO_RCVTIMEO = 20;
    private static final int SO_SNDTIMEO = 21;
    private static final int SOCK_CLOEXEC = 0x80000;   // atomico no socketpair (elimina a race de heranca de fd)
    private static final int EINTR = 4;                // interrompido por sinal -> reler
    private static final int EAGAIN = 11;              // == EWOULDBLOCK no Linux -> timeout do SO_*TIMEO
    private static final int SIGKILL = 9;
    private static final int WNOHANG = 1;
    private static final int FD_OSERVER = 6;   // fd bidirecional que o InitFD usa

    /** chdir mexe no estado GLOBAL do processo: serializa apenas a janela do spawn. */
    private static final Object SPAWN_LOCK = new Object();

    interface CLib extends Library {
        CLib INSTANCE = Native.load("c", CLib.class);

        int socketpair(int domain, int type, int protocol, int[] sv);

        int posix_spawn(IntByReference pid, String path, Pointer fileActions, Pointer attrp,
                        StringArray argv, StringArray envp);

        int posix_spawn_file_actions_init(Pointer fa);

        int posix_spawn_file_actions_destroy(Pointer fa);

        int posix_spawn_file_actions_adddup2(Pointer fa, int fd, int newfd);

        NativeLong read(int fd, byte[] buf, NativeLong count);

        NativeLong write(int fd, byte[] buf, NativeLong count);

        int close(int fd);

        int shutdown(int fd, int how);

        int fcntl(int fd, int cmd, int arg);

        int chdir(String path);

        Pointer getcwd(byte[] buf, NativeLong size);

        int setsockopt(int fd, int level, int optname, Pointer optval, int optlen);

        int waitpid(int pid, IntByReference status, int options);

        int kill(int pid, int sig);
    }

    /**
     * Executa o programa, envia {@code request} pelo fd bidirecional e devolve a resposta crua
     * (blocos do oserver). Lanca IOException em falha de spawn ou timeout sem dados.
     *
     * <p>Se {@code fasesNanos} (comprimento &gt;= 2) for passado, preenche a decomposicao de latencia
     * em nanos: [0] = setup/spawn (socketpair + posix_spawn) e [1] = roundtrip (write + read ate EOF,
     * que ~ equivale ao tempo de RESPOSTA do programa Pascal). Pode ser {@code null} p/ ignorar.</p>
     */
    static byte[] exchange(String bin, Map<String, String> env, String cwd, String ip,
                           byte[] request, long timeoutMs, long[] fasesNanos) throws IOException {
        CLib c = CLib.INSTANCE;
        long t0 = System.nanoTime();

        int[] sv = new int[2];
        // SOCK_CLOEXEC marca AMBOS os fds como close-on-exec ATOMICAMENTE (fix seçao 8 do TDD): elimina a
        // race em que um spawn concorrente de OUTRA thread herdava a ponta do socket (o EOF nunca chegava e a
        // chamada penduraava ate o timeout). Antes o fcntl(CLOEXEC) vinha DEPOIS do socketpair (janela aberta).
        if (c.socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, sv) != 0) {
            throw new IOException("socketpair falhou");
        }
        int parent = sv[0];
        int child = sv[1];

        // O adddup2(child -> fd 6) limpa o CLOEXEC no fd 6 do filho. Unica excecao: se o kernel devolveu
        // child == 6, dup2(6,6) e no-op e NAO limpa o flag -> limpa na mao p/ o programa manter o fd 6.
        if (child == FD_OSERVER) {
            c.fcntl(child, F_SETFD, 0);
        }

        Memory fa = new Memory(128);   // posix_spawn_file_actions_t (~80 bytes no glibc); folga de sobra
        fa.clear();
        c.posix_spawn_file_actions_init(fa);
        c.posix_spawn_file_actions_adddup2(fa, child, FD_OSERVER);

        StringArray argv = new StringArray(new String[]{bin, "6", "6", ip == null ? "127.0.0.1" : ip});
        StringArray envp = new StringArray(envArray(env));
        IntByReference pid = new IntByReference();

        int rc;
        synchronized (SPAWN_LOCK) {
            byte[] saveCwd = new byte[4096];
            Pointer got = c.getcwd(saveCwd, new NativeLong(saveCwd.length));
            boolean chdired = cwd != null && c.chdir(cwd) == 0;
            rc = c.posix_spawn(pid, bin, fa, null, argv, envp);
            if (chdired && got != null) {
                c.chdir(Native.toString(saveCwd));
            }
        }
        c.posix_spawn_file_actions_destroy(fa);
        c.close(child);   // o pai nao usa a ponta do filho

        if (rc != 0) {
            c.close(parent);
            throw new IOException("posix_spawn rc=" + rc);
        }

        // timeout de recepcao em MILISSEGUNDOS (struct timeval: tv_sec, tv_usec — 8+8 bytes no x86_64)
        Memory tv = new Memory(16);
        tv.setLong(0, timeoutMs / 1000);            // tv_sec
        tv.setLong(8, (timeoutMs % 1000) * 1000);   // tv_usec (resto em microssegundos)
        c.setsockopt(parent, SOL_SOCKET, SO_RCVTIMEO, tv, 16);
        c.setsockopt(parent, SOL_SOCKET, SO_SNDTIMEO, tv, 16);   // fix seçao 8: timeout tambem na ESCRITA
        long tSetup = System.nanoTime();   // fim do setup (socketpair + posix_spawn); dai pra frente e I/O

        try {
            writeAll(c, parent, request);
            c.shutdown(parent, SHUT_WR);     // sinaliza EOF para o programa

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[65536];
            while (true) {
                long n = c.read(parent, buf, new NativeLong(buf.length)).longValue();
                if (n > 0) {
                    out.write(buf, 0, (int) n);
                } else if (n == 0) {
                    break;                   // EOF: programa fechou o socket
                } else {   // n < 0: erro/timeout. Verifica o errno (fix seçao 8) — antes TUDO virava "timeout".
                    int errno = Native.getLastError();
                    if (errno == EINTR) {
                        continue;            // interrompido por sinal -> tenta ler de novo
                    }
                    // EAGAIN/EWOULDBLOCK = timeout do SO_RCVTIMEO; qualquer outro (ex.: ECONNRESET) = erro real.
                    // Em AMBOS os casos, resposta PARCIAL e ERRO — nunca retornar payload truncado (corrupcao silenciosa).
                    String causa = (errno == EAGAIN)
                            ? "Tempo excedido (" + timeoutMs + "ms)"
                            : "Erro de leitura (errno=" + errno + ")";
                    throw new IOException(causa + (out.size() > 0
                            ? " apos " + out.size() + " bytes parciais" : " sem resposta"));
                }
            }
            if (fasesNanos != null && fasesNanos.length >= 2) {
                fasesNanos[0] = tSetup - t0;                 // setup/spawn (socketpair + posix_spawn)
                fasesNanos[1] = System.nanoTime() - tSetup;  // roundtrip (~ tempo de resposta do Pascal)
            }
            return out.toByteArray();
        } finally {
            c.close(parent);
            colher(c, pid.getValue());
        }
    }

    private static void writeAll(CLib c, int fd, byte[] data) throws IOException {
        int off = 0;
        while (off < data.length) {
            byte[] chunk = off == 0 ? data : java.util.Arrays.copyOfRange(data, off, data.length);
            long n = c.write(fd, chunk, new NativeLong(chunk.length)).longValue();
            if (n <= 0) {
                throw new IOException("falha escrevendo no socket do programa");
            }
            off += (int) n;
        }
    }

    /** Colhe o filho (evita zumbi); se ainda estiver vivo, mata e colhe. */
    private static void colher(CLib c, int pid) {
        IntByReference status = new IntByReference();
        if (c.waitpid(pid, status, WNOHANG) == 0) {
            c.kill(pid, SIGKILL);
            c.waitpid(pid, status, 0);
        }
    }

    private static String[] envArray(Map<String, String> env) {
        String[] a = new String[env.size()];
        int i = 0;
        for (Map.Entry<String, String> e : env.entrySet()) {
            a[i++] = e.getKey() + "=" + e.getValue();
        }
        return a;
    }
}
