package com.prognum.scci;

import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

import com.prognum.launcher.model.ComandoExecucao;
import com.prognum.launcher.model.ResultadoExecucao;
import com.prognum.launcher.port.ExecutorPrograma;
import com.prognum.scci.acesso.domain.port.out.VersaoSistemaProvider;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Le a versao do SISTEMA direto da fonte da verdade — a constante {@code Versao}/{@code VersaoC} do
 * {@code smv.pas}, COMPILADA no binario Pascal — rodando {@code wverificascci/verificaversaoscci} via o SDK
 * embutido (so no deploy HIBRIDO). Substitui o valor fixo em config, que desatualizava a cada release do
 * Pascal. Cacheia por ambiente (a versao do binfpc so muda em deploy, que reinicia o processo).
 *
 * <p>No deploy PURO (sem SDK) ou em qualquer falha, devolve {@link Optional#empty()} — o check de versao
 * trata isso como "indeterminado" e NAO bloqueia o login (fail-open).</p>
 */
@Component
public class VersaoSistemaPascal implements VersaoSistemaProvider {

    private static final Logger log = LoggerFactory.getLogger(VersaoSistemaPascal.class);

    // programa/metodo dedicado de versao (wverificascci.pas: Registra('verificaversaoscci', ...) ->
    // ListaOut.addval('Versao', Versaoc)). Metodo registrado em MINUSCULO -> depende do fallback de
    // nome-exato do ProgramExecutor para ser alcancavel pelo reator.
    private static final String PROGRAMA = "wverificascci";
    private static final String METODO = "verificaversaoscci";

    // "Versao":"984" (JSON) | <Versao>984</Versao> (XML/PMEMORY) | Versao=984 — tolerante ao formato do corpo.
    private static final Pattern VERSAO = Pattern.compile("(?i)vers[aã]o\"?\\s*[:=>]\\s*\"?([0-9][0-9.]*)");

    private final ObjectProvider<ExecutorPrograma> sdk;   // presente so no HIBRIDO (SdkHibridoConfig)
    private final ConcurrentHashMap<String, String> cache = new ConcurrentHashMap<>();

    public VersaoSistemaPascal(ObjectProvider<ExecutorPrograma> sdk) {
        this.sdk = sdk;
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
        ExecutorPrograma executor = sdk.getIfAvailable();
        if (executor == null) {
            return Optional.empty();   // deploy PURO: sem Pascal para perguntar
        }
        try {
            // requestMethod vazio: montaMetodo nao prefixa verbo -> tenta "Verificaversaoscci" e, pelo
            // fallback de nome-exato, "verificaversaoscci" (como o programa registra). Sem corpo/stream.
            ComandoExecucao cmd = new ComandoExecucao(ambiente, PROGRAMA, METODO, "", "{}",
                    "", "127.0.0.1", false, null);
            ResultadoExecucao r = executor.executar(cmd);
            String versao = r.erro() ? null : extrairVersao(r.corpo());
            if (versao == null || versao.isBlank()) {
                log.warn("versao_sistema_sem_valor", kv("ambiente", ambiente), kv("erro", r.erro()));
                return Optional.empty();
            }
            cache.put(ambiente, versao);
            log.info("versao_sistema_lida", kv("ambiente", ambiente), kv("versao", versao));
            return Optional.of(versao);
        } catch (RuntimeException e) {
            log.warn("versao_sistema_falha", kv("ambiente", ambiente), kv("erro", String.valueOf(e.getMessage())));
            return Optional.empty();
        }
    }

    /** Extrai o valor da versao do corpo (JSON/XML/kv), tolerante ao formato. Pacote p/ teste. */
    static String extrairVersao(String corpo) {
        if (corpo == null) {
            return null;
        }
        Matcher m = VERSAO.matcher(corpo);
        return m.find() ? m.group(1) : null;
    }
}
