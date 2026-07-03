package com.prognum.common.environment;

import com.prognum.common.crypto.WcopCrypto;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Le o launcherenv.ini de um ambiente e devolve a {@link SccDbConfig} (secao [USERS]).
 * Fiel ao launcher.pas (TLauncherEnv.create / LoadDBUsers): mesmas chaves e defaults.
 * Copia fiel do launcher SCCI (legado). Infra COMPARTILHADA (autenticacao, identidade, execucao).
 */
public class LauncherEnvReader {

    public SccDbConfig ler(String ambientePath) {
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
        Path ini = Path.of(ambientePath, "launcherenv.ini");
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
                orDefault(users.get("USERMUSTCHANGE"), "IN_TROCA_SENHA_PROXIMO_LOGIN"));
    }

    private static String orDefault(String v, String def) {
        return (v == null || v.isBlank()) ? def : v;
    }

    private static String up(String v) {
        return v == null ? "" : v.trim().toUpperCase();
    }
}
