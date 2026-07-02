package com.prognum.launcher.documentos.port.in;

import com.prognum.launcher.documentos.model.Documento;

import java.util.List;

/** SCAFFOLD (port de entrada) do contexto DOCUMENTOS. Sem implementacao — regra a definir. */
public interface ConsultarDocumentosUseCase {

    List<Documento> listar(String ambiente);
}
