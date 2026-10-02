package com.prognum.common.environment;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * Traduz o ambiente "virtual" que o front envia (ex.: {@code /cfiae/}) para o caminho FÍSICO do
 * cliente (ex.: {@code /home/cfiae/dados/}). Porte fiel do {@code VirtualPathToFisical} do
 * {@code launcher.pas} (legado), que resolve pela seção {@code [DIRETORIOS]} do {@code launcher.conf}.
 *
 * <p>Regra (igual ao legado): tira UMA {@code /} inicial; percorre as entradas de {@code [DIRETORIOS]}
 * NA ORDEM do arquivo e usa a primeira cujo NOME é o começo do caminho seguido de {@code /};
 * devolve {@code <diretório configurado> + <resto do caminho a partir da '/'>}.</p>
 *
 * <p><b>Única diferença do legado:</b> quando NENHUMA entrada casa, o legado devolvia vazio (e o login
 * falhava); aqui devolvemos o caminho COMO VEIO. Assim quem já manda o caminho físico
 * ({@code /home/cfiae/dados}) continua entrando, e um ambiente sem {@code launcher.conf} (ex.: Docker)
 * não muda. Também torna a tradução IDEMPOTENTE (reaplicar sobre um caminho já físico devolve ele
 * mesmo), o que é seguro já que o gateway pode traduzir mais de uma vez no caminho da requisição.</p>
 *
 * <p>O arquivo é relido quando muda (mtime/tamanho). Thread-safe: o {@code snapshot} imutável é
 * trocado atomicamente. Fiel ao {@code Refresh} do legado: lê {@code launcher.conf} do diretório de
 * trabalho e, se não existir, o caminho configurado (default {@code /etc/launcher.conf}); normaliza
 * cada valor prefixando {@code /} quando ausente.</p>
 */
public final class ResolvedorAmbiente {

    /** Uma entrada de [DIRETORIOS]: nome virtual -> diretório físico (já normalizado com '/' inicial). */
    private record Entrada(String nome, String dir) {}

    /** Foto imutável do launcher.conf + metadados p/ detectar alteração. */
    private record Snapshot(List<Entrada> entradas, long mtime, long tamanho) {}

    private final Path confPath;
    private final Path confCwd = Path.of("launcher.conf");   // CWD tem prioridade (fiel ao Refresh)
    private volatile Snapshot snapshot;

    public ResolvedorAmbiente(String launcherConf) {
        this.confPath = (launcherConf == null || launcherConf.isBlank())
                ? Path.of("/etc/launcher.conf")
                : Path.of(launcherConf.trim());
        this.snapshot = carregar();
    }

    /**
     * Traduz o caminho virtual para o físico. {@code null}/vazio e "sem correspondência" voltam como
     * vieram (ver Javadoc da classe).
     */
    public String resolver(String virtualPath) {
        if (virtualPath == null || virtualPath.isEmpty()) {
            return virtualPath;
        }
        Snapshot s = snapshotAtual();
        // tira UMA '/' inicial (fiel: if copy(VirtualPath,1,1)='/' then delete(VirtualPath,1,1))
        String p = virtualPath.charAt(0) == '/' ? virtualPath.substring(1) : virtualPath;
        for (Entrada e : s.entradas()) {
            int len = e.nome().length();
            // começa com <nome> E o caractere seguinte é '/' (precisa sobrar algo além do nome)
            if (len > 0 && p.length() > len && p.startsWith(e.nome()) && p.charAt(len) == '/') {
                return e.dir() + p.substring(len);   // dir + '/resto' (fiel a Value + copy(,len+1,MaxInt))
            }
        }
        return virtualPath;   // sem match -> como veio (DIVERGÊNCIA proposital do legado, que dava vazio)
    }

    /** Relê o arquivo se ele mudou (mtime/tamanho); mantém o snapshot anterior em erro de I/O. */
    private Snapshot snapshotAtual() {
        Snapshot atual = snapshot;
        try {
            Path alvo = Files.exists(confCwd) ? confCwd : confPath;
            if (Files.exists(alvo)) {
                long mt = Files.getLastModifiedTime(alvo).toMillis();
                long tam = Files.size(alvo);
                if (mt != atual.mtime() || tam != atual.tamanho()) {
                    atual = carregar();
                    snapshot = atual;
                }
            } else if (!atual.entradas().isEmpty()) {
                atual = new Snapshot(List.of(), 0L, 0L);   // arquivo sumiu -> sem tradução
                snapshot = atual;
            }
        } catch (IOException ignore) {
            // erro transitório de I/O: segue com o snapshot que já tínhamos
        }
        return atual;
    }

    /** Lê e parseia [DIRETORIOS] do launcher.conf (CWD primeiro, senão o configurado). */
    private Snapshot carregar() {
        List<Entrada> entradas = new ArrayList<>();
        long mt = 0L;
        long tam = 0L;
        Path alvo = Files.exists(confCwd) ? confCwd : confPath;
        try {
            if (Files.exists(alvo)) {
                mt = Files.getLastModifiedTime(alvo).toMillis();
                tam = Files.size(alvo);
                boolean emDiretorios = false;
                for (String bruta : Files.readAllLines(alvo, StandardCharsets.ISO_8859_1)) {
                    String l = bruta.trim();
                    if (l.isEmpty() || l.startsWith("#") || l.startsWith(";")) {
                        continue;
                    }
                    if (l.startsWith("[") && l.endsWith("]")) {
                        emDiretorios = "DIRETORIOS".equalsIgnoreCase(l.substring(1, l.length() - 1).trim());
                        continue;
                    }
                    if (!emDiretorios) {
                        continue;
                    }
                    int eq = l.indexOf('=');
                    if (eq <= 0) {
                        continue;
                    }
                    String nome = l.substring(0, eq).trim();
                    String dir = l.substring(eq + 1).trim();
                    if (nome.isEmpty()) {
                        continue;
                    }
                    if (!dir.startsWith("/")) {
                        dir = "/" + dir;   // normaliza (fiel ao Refresh: prefixa PathDelim se faltar)
                    }
                    entradas.add(new Entrada(nome, dir));
                }
            }
        } catch (IOException ignore) {
            // sem arquivo/erro -> lista vazia -> resolver() devolve tudo como veio
        }
        return new Snapshot(List.copyOf(entradas), mt, tam);
    }
}
