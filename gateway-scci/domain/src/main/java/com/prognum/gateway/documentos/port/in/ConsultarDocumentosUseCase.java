package com.prognum.gateway.documentos.port.in;

import com.prognum.gateway.documentos.model.Documento;

import java.util.List;

/** SCAFFOLD (port de entrada) do contexto DOCUMENTOS. Sem implementacao — regra a definir. */
public interface ConsultarDocumentosUseCase {

    List<Documento> listar(String ambiente);
}
