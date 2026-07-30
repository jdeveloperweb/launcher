package com.prognum.gateway.execucao;

import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;
import com.prognum.gateway.execucao.port.in.DespachoUseCase;
import com.prognum.gateway.execucao.port.out.ExecutorPrograma;
import com.prognum.gateway.execucao.port.out.RotaExecucaoRegistry;

/**
 * Roteador da EXECUÇÃO {@code /w} (Strangler, 3 trilhos). Por operação, a feature-flag
 * ({@link RotaExecucaoRegistry}) decide o destino — e delega ao executor certo:
 *
 * <ul>
 *   <li><b>puro</b>    → scci-core PURO   (Java puro, sem Pascal);</li>
 *   <li><b>hibrido</b> → scci-core HÍBRIDO (Java + Pascal via SDK);</li>
 *   <li><b>pascal</b>  → executor Pascal direto (legado — o default).</li>
 * </ul>
 *
 * Os três destinos falam o MESMO contrato ({@code /interno/executar}); muda só a URL. A validação de
 * sessão já foi feita no adapter de entrada. POJO puro (o trilho escolhido é logado lá no controller).
 */
public class RoteadorExecucao implements DespachoUseCase {

    private final ExecutorPrograma pascal;
    private final ExecutorPrograma hibrido;
    private final ExecutorPrograma puro;
    private final RotaExecucaoRegistry rotas;

    public RoteadorExecucao(ExecutorPrograma pascal, ExecutorPrograma hibrido,
                            ExecutorPrograma puro, RotaExecucaoRegistry rotas) {
        this.pascal = pascal;
        this.hibrido = hibrido;
        this.puro = puro;
        this.rotas = rotas;
    }

    @Override
    public ResultadoExecucao despachar(ComandoExecucao comando) {
        return executorDe(rotas.trilho(comando.programName())).executar(comando);
    }

    private ExecutorPrograma executorDe(String trilho) {
        return switch (trilho) {
            case "puro" -> puro;
            case "hibrido" -> hibrido;
            default -> pascal;
        };
    }
}
