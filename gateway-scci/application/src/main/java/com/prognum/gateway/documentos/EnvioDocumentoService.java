package com.prognum.gateway.documentos;

import com.prognum.gateway.documentos.port.in.EnviarDocumentoUseCase;
import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;
import com.prognum.gateway.execucao.port.out.ExecutorPrograma;

import java.util.ArrayList;
import java.util.List;

/**
 * Upload de documentos (canal sccidoc / putDoc), do jeito Java. Espelha o laco do DoMultiPartRemoteCall
 * do sccidoc.pas: executa o programa UMA vez por arquivo (o {@link ComandoExecucao} ja carrega os bytes
 * do arquivo em {@code corpoBinario}, que o {@link ExecutorPrograma} anexa apos os params size-prefixed)
 * e coleta o corpo JSON de cada execucao. A juncao das respostas (success/message/dados) fica no adapter
 * de entrada, que tem o parser JSON. POJO puro.
 */
public class EnvioDocumentoService implements EnviarDocumentoUseCase {

    private final ExecutorPrograma executor;

    public EnvioDocumentoService(ExecutorPrograma executor) {
        this.executor = executor;
    }

    @Override
    public List<String> enviar(List<ComandoExecucao> arquivos) {
        List<String> respostas = new ArrayList<>(arquivos.size());
        for (ComandoExecucao comando : arquivos) {
            ResultadoExecucao r = executor.executar(comando);
            respostas.add(r.corpo());
        }
        return respostas;
    }
}
