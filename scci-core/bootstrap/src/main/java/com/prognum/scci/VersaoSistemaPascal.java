package com.prognum.scci;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.scci.acesso.domain.port.out.VersaoSistemaProvider;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Le a versao do SISTEMA executando o programa DEDICADO {@code scciver} (scci-backend/scci/tools/scciver.pas,
 * cujo comentario e "programa imprime a versao do scci"): a 1a instrucao e {@code writeln(VersaoC)}, SEM
 * tocar o banco — so grava {@code VERSAO_INST} com o arg {@code 'A'} (a rotina do inst.sh), que NAO passamos.
 * Fiel a "nao reimplementar, executar": a versao vem do binario compilado (constante {@code smv}) daquele
 * binfpc, impressa no stdout.
 *
 * <p>Roda via {@link ProcessBuilder} (CLI, nao oserver), cacheia por ambiente (a versao do binfpc so muda em
 * deploy, que reinicia o processo). Binario ausente (ex.: deploy puro sem Pascal) ou qualquer falha =>
 * {@link Optional#empty()} = o check NAO bloqueia o login (fail-open).</p>
 */
@Component
public class VersaoSistemaPascal implements VersaoSistemaProvider {

    private static final Logger log = LoggerFactory.getLogger(VersaoSistemaPascal.class);
    private static final String PROGRAMA = "scciver";
    private static final long TIMEOUT_SEG = 10;

    private final LauncherEnvReader env;
    private final ConcurrentHashMap<String, String> cache = new ConcurrentHashMap<>();

    public VersaoSistemaPascal(LauncherEnvReader env) {
        this.env = env;
    }

    @Override
    public Optional<String> versaoSistema(String ambiente) {
        if (ambiente == null || ambiente.isBlank()) {
            return Optional.empty();
        }
        String cached = cache.get(ambiente);
        if (cached != null) {
            return Optional.of(cached);
        }
        try {
            Map<String, String> ambEnv = env.ambienteEnv(ambiente, "");
            String bin = resolverBinario(PROGRAMA, ambEnv.get("PATH"), ambiente);
            if (bin == null) {
                log.warn("versao_sistema_scciver_ausente", kv("ambiente", ambiente));
                return Optional.empty();
            }
            String versao = primeiraVersao(executar(bin, ambEnv, ambiente));
            if (versao == null) {
                log.warn("versao_sistema_sem_valor", kv("ambiente", ambiente));
                return Optional.empty();
            }
            cache.put(ambiente, versao);
            log.info("versao_sistema_lida", kv("ambiente", ambiente), kv("versao", versao), kv("via", PROGRAMA));
            return Optional.of(versao);
        } catch (Exception e) {
            log.warn("versao_sistema_falha", kv("ambiente", ambiente), kv("erro", String.valueOf(e.getMessage())));
            return Optional.empty();
        }
    }

    /** Roda {@code scciver} (sem arg -> so imprime VersaoC, nao grava banco) e devolve a 1a linha do stdout. */
    private String executar(String bin, Map<String, String> ambEnv, String cwd) throws Exception {
        ProcessBuilder pb = new ProcessBuilder(bin);
        pb.directory(new File(cwd));
        pb.environment().putAll(ambEnv);        // PATH/ORACLE_HOME/... do ambiente (aditivo ao env herdado)
        pb.redirectErrorStream(false);          // stderr separado: warnings de lib nao poluem o stdout
        Process p = pb.start();
        String linha;
        try (BufferedReader r = new BufferedReader(
                new InputStreamReader(p.getInputStream(), StandardCharsets.ISO_8859_1))) {
            linha = r.readLine();               // scciver escreve a versao na 1a linha
        }
        if (!p.waitFor(TIMEOUT_SEG, TimeUnit.SECONDS)) {
            p.destroyForcibly();
            return null;
        }
        return linha;
    }

    /**
     * Valida/extrai a versao da linha do stdout: digitos com ponto/letra de patch opcionais
     * (ex.: {@code "984"}, {@code "9.84"}, {@code "983a"}). Linha que nao casa (warning de lib, vazio) =>
     * {@code null} (fail-open). Pacote p/ teste.
     */
    static String primeiraVersao(String linha) {
        if (linha == null) {
            return null;
        }
        String t = linha.trim();
        return t.matches("[0-9][0-9.]*[A-Za-z]?") ? t : null;
    }

    /** Acha o binario no PATH do ambiente, senao em {@code <ambiente>/binfpc} e {@code /u/scci/binfpc}. */
    private static String resolverBinario(String programa, String path, String ambiente) {
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
            File f = new File(d, programa);
            if (f.isFile() && f.canExecute()) {
                return f.getAbsolutePath();
            }
        }
        return null;
    }
}
