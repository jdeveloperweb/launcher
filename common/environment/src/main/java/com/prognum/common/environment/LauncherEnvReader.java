package com.prognum.common.environment;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import com.prognum.common.crypto.WcopCrypto;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Le o launcherenv.ini de um ambiente e devolve a {@link SccDbConfig} (secao [USERS]).
 * Fiel ao launcher.pas (TLauncherEnv.create / LoadDBUsers): mesmas chaves e defaults.
 * Copia fiel do launcher SCCI (legado). Infra COMPARTILHADA (autenticacao, identidade, execucao).
 *
 * <p><b>Doc Final de Requisitos (Autenticacao/Sessao):</b> cache opcional e parametrizavel da
 * leitura do launcherenv.ini por ambiente (arquivo de config que raramente muda) — evita reler/
 * reparsear o .ini do disco em toda requisicao. NAO cacheia credencial/senha de USUARIO final (essa
 * fica sempre lida ao vivo no banco, decisao deliberada para nao manter login valido apos troca de
 * senha durante o TTL do cache). {@code cacheHabilitado=false} preserva o comportamento antigo
 * (sempre le do disco). POJO puro — Caffeine e biblioteca JDK, sem dependencia de Spring.</p>
 */
public class LauncherEnvReader {

    private final boolean cacheHabilitado;
    private final Cache<String, SccDbConfig> cache;

    /** Compat: sem cache (sempre le do disco) — comportamento anterior a este requisito. */
    public LauncherEnvReader() {
        this(false, 0);
    }

    /**
     * @param cacheHabilitado liga/desliga o cache (politica de uso — Doc Final de Requisitos).
     * @param cacheTtlSegundos tempo de vida de cada entrada; {@code <=0} com cache habilitado = sem
     *                         expiracao por tempo (só sai por invalidação manual).
     */
    public LauncherEnvReader(boolean cacheHabilitado, long cacheTtlSegundos) {
        this.cacheHabilitado = cacheHabilitado;
        Caffeine<Object, Object> builder = Caffeine.newBuilder();
        if (cacheTtlSegundos > 0) {
            builder.expireAfterWrite(Duration.ofSeconds(cacheTtlSegundos));
        }
        this.cache = builder.build();
    }

    public SccDbConfig ler(String ambientePath) {
        if (!cacheHabilitado) {
            return lerDoDisco(ambientePath);
        }
        return cache.get(ambientePath, this::lerDoDisco);
    }

    /** Politica de invalidacao (Doc Final de Requisitos): remove um ambiente específico do cache. */
    public void invalidar(String ambientePath) {
        cache.invalidate(ambientePath);
    }

    /** Politica de invalidacao: limpa o cache inteiro (ex.: apos alteracao em lote nos .ini). */
    public void invalidarTudo() {
        cache.invalidateAll();
    }

    private SccDbConfig lerDoDisco(String ambientePath) {
        Path ini = Path.of(ambientePath, "launcherenv.ini");
        try {
            return parse(Files.readAllLines(ini, StandardCharsets.ISO_8859_1));
        } catch (IOException e) {
            throw new IllegalStateException("nao foi possivel ler " + ini, e);
        }
    }

    /**
     * Variaveis de ambiente do ambiente (secao [ENVIRONMENT] do launcherenv.ini) + USER,
     * para o launcher EXECUTAR os programas com o mesmo ambiente que o daemon monta (SetAmbiente).
     * Expande referencias $VAR/${VAR}.
     */
    public Map<String, String> ambienteEnv(String ambientePath, String usuario) {
        Map<String, String> env = new LinkedHashMap<>();
        env.put("USER", usuario == null ? "" : usuario);
        // Fiel ao legado (sccidef.pas:11129 -> GetEnv('SCCIDIRATV')+'/launcherenv.ini'): o DIR do
        // ambiente vem da env var SCCIDIRATV, NAO do path cru do request. Necessario no gateway em
        // CONTAINER, onde o ambienteOperacional pode chegar como /u6/... (symlink do host que o container
        // nao monta) e a leitura estoura (500 no login). Setando SCCIDIRATV no container com o path que
        // ele ENXERGA (ex.: /home/abc/dados314), o reator le do lugar certo. Sem a env var, cai no path
        // do request (preserva multi-ambiente nas deployments que nao a setam).
        String dir = System.getenv("SCCIDIRATV");
        if (dir == null || dir.isBlank()) {
            dir = ambientePath;
        }
        Path ini = Path.of(dir, "launcherenv.ini");
        List<String> linhas;
        try {
            linhas = Files.readAllLines(ini, StandardCharsets.ISO_8859_1);
        } catch (IOException e) {
            throw new IllegalStateException("nao foi possivel ler " + ini, e);
        }
        String secao = "";
        for (String bruta : linhas) {
            String l = bruta.trim();
            if (l.isEmpty() || l.startsWith("#") || l.startsWith(";")) {
                continue;
            }
            if (l.startsWith("[") && l.endsWith("]")) {
                secao = l.substring(1, l.length() - 1).trim().toUpperCase();
                continue;
            }
            int eq = l.indexOf('=');
            if (eq > 0 && "ENVIRONMENT".equals(secao)) {
                env.put(l.substring(0, eq).trim(), expandir(l.substring(eq + 1).trim(), env));
            }
        }
        return env;
    }

    /**
     * Comandos da secao [LOG] do launcherenv.ini (LOGIN/LOGOFF/LOGINERR/LOGPASSWD) — o launcher roda o
     * programa configurado (ex.: {@code sccilog -z LOGON $USER}) em cada evento de acesso. Mapa VAZIO =
     * sem log de evento (secao/arquivo ausente): e OPCIONAL por cliente (config-driven).
     */
    public Map<String, String> logEventos(String ambientePath) {
        Map<String, String> logs = new LinkedHashMap<>();
        Path ini = Path.of(ambientePath, "launcherenv.ini");
        List<String> linhas;
        try {
            linhas = Files.readAllLines(ini, StandardCharsets.ISO_8859_1);
        } catch (IOException e) {
            return logs;   // sem arquivo -> sem log de evento
        }
        String secao = "";
        for (String bruta : linhas) {
            String l = bruta.trim();
            if (l.isEmpty() || l.startsWith("#") || l.startsWith(";")) {
                continue;
            }
            if (l.startsWith("[") && l.endsWith("]")) {
                secao = l.substring(1, l.length() - 1).trim().toUpperCase();
                continue;
            }
            int eq = l.indexOf('=');
            if (eq > 0 && "LOG".equals(secao)) {
                logs.put(l.substring(0, eq).trim().toUpperCase(), l.substring(eq + 1).trim());
            }
        }
        return logs;
    }

    /** Politica de senha POR AMBIENTE (secao [USERS] do launcherenv.ini). Chaves ausentes = 0 = sem exigencia. */
    public PoliticaSenhaIni politicaSenha(String ambientePath) {
        Map<String, String> u = secao(ambientePath, "USERS");
        return new PoliticaSenhaIni(
                inteiro(u, "USERMINCARACPASS"), inteiro(u, "CARMINALFAPASS"), inteiro(u, "CARMINALFAMAISPASS"),
                inteiro(u, "CARMINNUMPASS"), inteiro(u, "CARMINESPPASS"),
                inteiro(u, "USERMAXREPPASS"), inteiro(u, "USERMAXSEQPASS"));
    }

    /** Limite de sessoes simultaneas por usuario (ACESSOSSIMULTANEOS do [ENVIRONMENT]). 0 = ausente/ilimitado. */
    public int acessosSimultaneos(String ambientePath) {
        return inteiro(secao(ambientePath, "ENVIRONMENT"), "ACESSOSSIMULTANEOS");
    }

    /** Le uma secao crua do launcherenv.ini (chaves em MAIUSCULO). Vazio se o arquivo nao existir. */
    private Map<String, String> secao(String ambientePath, String secaoAlvo) {
        Map<String, String> vals = new LinkedHashMap<>();
        Path ini = Path.of(ambientePath, "launcherenv.ini");
        List<String> linhas;
        try {
            linhas = Files.readAllLines(ini, StandardCharsets.ISO_8859_1);
        } catch (IOException e) {
            return vals;
        }
        String sec = "";
        for (String bruta : linhas) {
            String l = bruta.trim();
            if (l.isEmpty() || l.startsWith("#") || l.startsWith(";")) {
                continue;
            }
            if (l.startsWith("[") && l.endsWith("]")) {
                sec = l.substring(1, l.length() - 1).trim().toUpperCase();
                continue;
            }
            int eq = l.indexOf('=');
            if (eq > 0 && secaoAlvo.equals(sec)) {
                vals.put(l.substring(0, eq).trim().toUpperCase(), l.substring(eq + 1).trim());
            }
        }
        return vals;
    }

    private static int inteiro(Map<String, String> m, String chave) {
        try {
            String v = m.get(chave);
            return (v == null || v.isBlank()) ? 0 : Integer.parseInt(v.trim());
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** Expande $VAR/${VAR} num valor usando o mapa de ambiente — publico p/ reuso (ex.: comandos [LOG]). */
    public static String expandirVariaveis(String valor, Map<String, String> env) {
        return expandir(valor, env);
    }

    /** Expande $VAR e ${VAR} usando o env ja montado (ou o do SO). */
    private static String expandir(String valor, Map<String, String> env) {
        Matcher m = Pattern.compile("\\$\\{?([A-Za-z_][A-Za-z0-9_]*)\\}?").matcher(valor);
        StringBuilder sb = new StringBuilder();
        while (m.find()) {
            String nome = m.group(1);
            String v = env.get(nome);
            if (v == null) {
                v = System.getenv(nome);
            }
            m.appendReplacement(sb, Matcher.quoteReplacement(v == null ? "" : v));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    /** Parser INI simples: secao [X] e chaves CHAVE=VALOR (ignora # e ;). */
    SccDbConfig parse(List<String> linhas) {
        Map<String, String> users = new LinkedHashMap<>();
        String secao = "";
        for (String bruta : linhas) {
            String l = bruta.trim();
            if (l.isEmpty() || l.startsWith("#") || l.startsWith(";")) {
                continue;
            }
            if (l.startsWith("[") && l.endsWith("]")) {
                secao = l.substring(1, l.length() - 1).trim().toUpperCase();
                continue;
            }
            int eq = l.indexOf('=');
            if (eq > 0 && "USERS".equals(secao)) {
                users.put(l.substring(0, eq).trim().toUpperCase(), l.substring(eq + 1).trim());
            }
        }

        String senha = users.getOrDefault("DB_PASS", "");
        senha = WcopCrypto.trataSenhaEncriptografada(senha);   // [..] -> WebDeCrypt; senao texto

        String driver = up(users.getOrDefault("DRIVERNAME", "INTERBASE"));
        if (driver.isEmpty()) {
            driver = "INTERBASE";
        }
        return new SccDbConfig(
                driver,
                users.getOrDefault("DB_HOSTNAME", ""),
                users.getOrDefault("DB", ""),
                users.getOrDefault("DB_USER", ""),
                senha,
                orDefault(users.get("USERTABLE"), "USUARIO"),
                orDefault(users.get("USERFIELD"), "CO_USUARIO"),
                orDefault(users.get("USERPASSWORD"), "CO_SENHA"),
                orDefault(users.get("USERDTVALID"), "DT_VALIDADE_USUARIO"),
                orDefault(users.get("USERLASTPASS"), "DT_ULTIMA_TROCA_SENHA"),
                orDefault(users.get("USERMAXPASS"), "NU_MAX_DIAS_TROCA_SENHA"),
                orDefault(users.get("USERMINPASS"), "NU_MIN_DIAS_TROCA_SENHA"),
                orDefault(users.get("USERMUSTCHANGE"), "IN_TROCA_SENHA_PROXIMO_LOGIN"),
                orDefault(users.get("USERACTIVE"), ""));   // ausente = sem coluna de inativacao
    }

    private static String orDefault(String v, String def) {
        return (v == null || v.isBlank()) ? def : v;
    }

    private static String up(String v) {
        return v == null ? "" : v.trim().toUpperCase();
    }
}
