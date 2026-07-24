package com.prognum.gateway.execucao;

import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;
import com.prognum.gateway.execucao.port.out.ExecutorPrograma;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Despacho /w: delega ao executor do programa "w" (a validação de sessão é feita no adapter). */
class DespachoServiceTest {

    private final ExecutorPrograma executor = mock(ExecutorPrograma.class);
    private final DespachoService svc = new DespachoService(executor);

    @Test
    void despachar_delega_ao_executor() {
        ComandoExecucao cmd = new ComandoExecucao("/amb", "wtela", "menu", "GET", "{}", "joao", "ip");
        ResultadoExecucao esperado = new ResultadoExecucao(false, "{\"dados\":{}}");
        when(executor.executar(any())).thenReturn(esperado);

        assertThat(svc.despachar(cmd)).isSameAs(esperado);
        verify(executor).executar(cmd);
    }
}
