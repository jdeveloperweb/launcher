package com.prognum.scci.acesso.adapters.out;

import com.prognum.scci.acesso.domain.port.out.VerificadorVersaoBanco;
import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.SccDbConfig;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.Optional;

/**
 * Adapter de saida: porte FIEL do {@code TestaVersaoBanco} do wae.pas — a validacao inicial de versao
 * do banco no login, disparada por {@code VERIFICAVERSAOBANCO} (secao [ENVIRONMENT] do launcherenv.ini).
 *
 * <p>Le a maior versao instalada na base ({@code SELECT NU_VERSAO, DT_PROC_INST FROM VERSAO_INST
 * ORDER BY NU_VERSAO DESC}) e compara com a versao do SISTEMA (a constante {@code Versao} do smv.pas,
 * hoje {@code '9.83'} — exposta como {@code scci.auth.versao-sistema}). Bloqueia o login quando:</p>
 * <ol>
 *   <li>a versao do banco difere da do sistema ({@code VersaoDb <> Versao} no legado); ou</li>
 *   <li>a rotina de instalacao (inst.sh) ainda nao foi processada — {@code DT_PROC_INST} nulo, que
 *       no legado e {@code juliano(DateTimeToData(DtProcInst)) <= 0} (data nula => juliano <= 0).</li>
 * </ol>
 *
 * <p><b>Versao do sistema:</b> no legado ela e COMPILADA no binario (smv.pas). Aqui vem por
 * configuracao ({@code scci.auth.versao-sistema}, default {@code 9.83}) e DEVE ser atualizada junto
 * com cada release do Pascal, exatamente como a constante {@code Versao} e bumpada la. SOMENTE LEITURA.</p>
 */
@Component
public class SccVersaoBancoRepository implements VerificadorVersaoBanco {

    // Mensagens IDENTICAS as do wae.pas (o QA compara AEJS Pascal x AEJS Java pelo texto).
    private static final String MSG_VERSAO_INCOMPATIVEL =
            "Versão do Banco de Dados incompatível com a versão do Sistema";
    private static final String MSG_INST_PENDENTE =
            "Atenção: Processe a rotina de instalação da versão (inst.sh) antes de acessar ao sistema.";

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;
    private final String versaoSistema;

    public SccVersaoBancoRepository(LauncherEnvReader env, JdbcConnectionFactory connections,
            @Value("${scci.auth.versao-sistema:9.83}") String versaoSistema) {
        this.env = env;
        this.connections = connections;
        this.versaoSistema = versaoSistema == null ? "" : versaoSistema.trim();
    }

    @Override
    public Optional<String> incompatibilidade(String ambiente) {
        // VERIFICAVERSAOBANCO: roda a menos que declarada EXATAMENTE 'FALSE' (fiel ao wae.pas:
        // upStr(GetEnv('VERIFICAVERSAOBANCO')) <> 'FALSE' — ausente/vazia => LIGADA).
        if (!env.verificaVersaoBanco(ambiente)) {
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

        // 1) versao do banco tem que ser IGUAL a do sistema (VersaoDb <> Versao => bloqueia)
        if (!versaoSistema.equals(versaoDb.trim())) {
            return Optional.of(MSG_VERSAO_INCOMPATIVEL);
        }
        // 2) instalacao processada: DT_PROC_INST nulo == juliano(...) <= 0 no legado => inst.sh pendente
        if (dtProcInst == null) {
            return Optional.of(MSG_INST_PENDENTE);
        }
        return Optional.empty();
    }
}
