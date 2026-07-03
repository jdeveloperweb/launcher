package com.prognum.launcher.documentos.port.out;

import com.prognum.launcher.documentos.model.Documento;

import java.util.List;

/** SCAFFOLD (port de saida) do contexto DOCUMENTOS. Fonte de dados a definir. */
public interface RepositorioDocumentos {

    List<Documento> listar(String ambiente);
}
