package com.prognum.common.environment;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Recarga da configuracao em runtime — o equivalente ao SIGHUP do launcher legado ({@code tratahup}:
 * {@code LauncherIni.Refresh} + {@code LauncherEnvList.Clear}), que rele TUDO de uma vez: o launcher.conf
 * ([DIRETORIOS], [ENV]) e o launcherenv.ini dos ambientes ([ENVIRONMENT], [USERS], [SEGURANCA], [LOG]...).
 *
 * <p>Cada servico (gateway, scci-core, pascal-executor) tem os seus caches e expoe o
 * {@code POST /admin/env/reload} com esta classe; os caches proprios do servico entram como
 * {@code extras} (ex.: o [DIRETORIOS] do gateway, a versao do sistema do scci-core). O ambiente dos
 * programas ([ENV] + [ENVIRONMENT], ex.: DATAH) nao tem cache: e lido do disco a cada execucao, e a
 * resposta mostra o valor efetivo das variaveis pedidas para conferir. POJO puro.</p>
 */
public final class RecargaAmbiente {

    private final LauncherEnvReader env;
    private final List<Runnable> extras;

    public RecargaAmbiente(LauncherEnvReader env, Runnable... extras) {
        this.env = env;
        this.extras = List.of(extras);
    }

    /**
     * Sem ambiente: limpa o cache de todos os ambientes; com ambiente (caminho fisico): so o dele. Nos dois
     * casos rele o que e global ({@code extras}). Com ambiente e variaveis, devolve o valor efetivo delas.
     */
    public Map<String, Object> recarregar(String ambiente, List<String> variaveis) {
        boolean todos = ambiente == null || ambiente.isBlank();
        if (todos) {
            env.invalidarTudo();
        } else {
            env.invalidar(ambiente);
        }
        extras.forEach(Runnable::run);

        Map<String, Object> r = new LinkedHashMap<>();
        r.put("success", true);
        r.put("reloaded", todos ? "all" : ambiente);
        if (variaveis != null && !variaveis.isEmpty()) {
            if (todos) {
                r.put("aviso", "informe ?ambiente= para ver o valor das variaveis");
            } else {
                try {
                    r.put("variaveis", env.variaveisEfetivas(ambiente, variaveis));
                } catch (IllegalStateException e) {
                    r.put("erro", e.getMessage());   // launcherenv.ini do ambiente nao encontrado/ilegivel
                }
            }
        }
        return r;
    }
}
