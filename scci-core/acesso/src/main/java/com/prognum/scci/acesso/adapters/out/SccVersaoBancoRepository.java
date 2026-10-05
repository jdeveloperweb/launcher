package com.prognum.scci.acesso.adapters.out;

import com.prognum.scci.acesso.domain.port.out.VerificadorVersaoBanco;
import com.prognum.scci.acesso.domain.port.out.VersaoSistemaProvider;
import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.SccDbConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.Optional;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Adapter de saida: porte FIEL do {@code TestaVersaoBanco} do wae.pas — a validacao inicial de versao
 * do banco no login, disparada por {@code VERIFICAVERSAOBANCO} (secao [ENVIRONMENT] do launcherenv.ini).
 *
 * <p>Le a maior versao instalada na base ({@code SELECT NU_VERSAO, DT_PROC_INST FROM VERSAO_INST
 * ORDER BY NU_VERSAO DESC}) e compara com a versao do SISTEMA. Bloqueia o login quando:</p>
 * <ol>
 *   <li>a versao do banco difere da do sistema ({@code VersaoDb <> Versao} no legado); ou</li>
 *   <li>a rotina de instalacao (inst.sh) ainda nao foi processada — {@code DT_PROC_INST} nulo, que
 *       no legado e {@code juliano(DateTimeToData(DtProcInst)) <= 0} (data nula => juliano <= 0).</li>
 * </ol>
 *
 * <p><b>Versao do sistema:</b> lida da FONTE DA VERDADE — a constante {@code Versao}/{@code VersaoC} do
 * {@code smv.pas}, compilada no binario Pascal — via {@link VersaoSistemaProvider} (NAO mais de config,
 * que desatualizava a cada release). Se o provider nao conseguir determinar a versao (deploy puro, falha),
 * o check NAO bloqueia (fail-open).</p>
 *
 * <p><b>Comparacao:</b> alinha os formatos removendo apenas o PONTO (a fonte da o compacto {@code "984"}/
 * {@code "983a"} e {@code NU_VERSAO} vem pontuado {@code "9.84"}/{@code "9.83a"}) e PRESERVA a LETRA do patch
 * e o case — {@code "9.83a"} NAO pode passar por {@code "9.83"} (fiel ao {@code VersaoDb <> Versao} exato do
 * legado; o {@code VersaoC} e o {@code Versao} sem o ponto, entao a letra sobrevive). SOMENTE LEITURA.</p>
 */
@Component
public class SccVersaoBancoRepository implements VerificadorVersaoBanco {

    private static final Logger log = LoggerFactory.getLogger(SccVersaoBancoRepository.class);

    // Mensagens IDENTICAS as do wae.pas (o QA compara AEJS Pascal x AEJS Java pelo texto).
    private static final String MSG_VERSAO_INCOMPATIVEL =
            "Versão do Banco de Dados incompatível com a versão do Sistema";
    private static final String MSG_INST_PENDENTE =
            "Atenção: Processe a rotina de instalação da versão (inst.sh) antes de acessar ao sistema.";

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;
    private final VersaoSistemaProvider versaoProvider;

    public SccVersaoBancoRepository(LauncherEnvReader env, JdbcConnectionFactory connections,
            VersaoSistemaProvider versaoProvider) {
        this.env = env;
        this.connections = connections;
        this.versaoProvider = versaoProvider;
    }

    @Override
    public Optional<String> incompatibilidade(String ambiente) {
        // VERIFICAVERSAOBANCO: roda a menos que declarada EXATAMENTE 'FALSE' (fiel ao wae.pas:
        // upStr(GetEnv('VERIFICAVERSAOBANCO')) <> 'FALSE' — ausente/vazia => LIGADA).
        if (!env.verificaVersaoBanco(ambiente)) {
            return Optional.empty();
        }

        // versao do SISTEMA: da fonte real (binario Pascal), nao de config. Indeterminavel => fail-open.
        String sistema = versaoProvider.versaoSistema(ambiente).map(SccVersaoBancoRepository::normalizaVersao).orElse("");
        if (sistema.isEmpty()) {
            log.warn("versao_sistema_indeterminada_login_liberado", kv("ambiente", ambiente));
            return Optional.empty();
        }

        SccDbConfig c = env.ler(ambiente);
        String versaoDb = "";
        Timestamp dtProcInst = null;
        String sql = "SELECT NU_VERSAO, DT_PROC_INST FROM VERSAO_INST ORDER BY NU_VERSAO DESC";
        try (Connection conn = connections.abrir(c, true);
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            if (rs.next()) {   // maior NU_VERSAO instalada (mesma ordenacao do legado)
                versaoDb = rs.getString("NU_VERSAO");
                if (versaoDb == null) {
                    versaoDb = "";
                }
                dtProcInst = rs.getTimestamp("DT_PROC_INST");
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao verificar VERSAO_INST no ambiente "
                    + c.host() + "/" + c.database(), e);
        }

        // 1) versao do banco tem que ser IGUAL a do sistema (VersaoDb <> Versao => bloqueia). Alinha o
        //    formato tirando so o ponto (compacto "983a" x pontuado "9.83a") e MANTEM a letra do patch.
        if (!sistema.equals(normalizaVersao(versaoDb))) {
            return Optional.of(MSG_VERSAO_INCOMPATIVEL);
        }
        // 2) instalacao processada: DT_PROC_INST nulo == juliano(...) <= 0 no legado => inst.sh pendente
        if (dtProcInst == null) {
            return Optional.of(MSG_INST_PENDENTE);
        }
        return Optional.empty();
    }

    /**
     * Alinha compacto (VersaoC {@code "983a"}) x pontuado (NU_VERSAO {@code "9.83a"}) tirando SO o ponto;
     * PRESERVA a letra do patch e o case. Assim {@code "9.83a"} -> {@code "983a"} NAO casa com {@code "9.83"}
     * -> {@code "983"} (a letra conta, fiel ao {@code <>} exato do legado).
     */
    static String normalizaVersao(String v) {
        return v == null ? "" : v.trim().replace(".", "");
    }
}
