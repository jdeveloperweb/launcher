package com.prognum.gateway.documentos;

import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;
import com.prognum.gateway.execucao.port.out.ExecutorPrograma;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Upload (putDoc): 1 execução por arquivo, coletando o corpo JSON de cada (DoMultiPartRemoteCall). */
class EnvioDocumentoServiceTest {

    private final ExecutorPrograma executor = mock(ExecutorPrograma.class);
    private final EnvioDocumentoService svc = new EnvioDocumentoService(executor);

    private ComandoExecucao arquivo(byte[] bytes) {
        return new ComandoExecucao("/amb", "wdoc", "documentoOperacao", "POST", "{}", "joao", "ip", true, bytes);
    }

    @Test
    void executa_uma_vez_por_arquivo_e_coleta_as_respostas() {
        ComandoExecucao a = arquivo(new byte[]{1});
        ComandoExecucao b = arquivo(new byte[]{2});
        when(executor.executar(a)).thenReturn(new ResultadoExecucao(false, "{\"success\":true,\"id\":1}"));
        when(executor.executar(b)).thenReturn(new ResultadoExecucao(false, "{\"success\":true,\"id\":2}"));

        List<String> respostas = svc.enviar(List.of(a, b));

        assertThat(respostas).containsExactly("{\"success\":true,\"id\":1}", "{\"success\":true,\"id\":2}");
        verify(executor, times(2)).executar(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void lista_vazia_nao_executa_nada() {
        assertThat(svc.enviar(List.of())).isEmpty();
        verify(executor, times(0)).executar(org.mockito.ArgumentMatchers.any());
    }
}
