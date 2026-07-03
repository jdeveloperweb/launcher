package com.prognum.scci.documentos.application;

import com.prognum.scci.documentos.domain.port.in.ExcluirDocumento;
import com.prognum.scci.documentos.domain.port.out.RepositorioDocumento;

/** Exclusão de documento (DeleteDocumento/ExcluiItem): delega ao repositório o delete de todas as versões. */
public class ExcluirDocumentoService implements ExcluirDocumento {

    private final RepositorioDocumento repo;

    public ExcluirDocumentoService(RepositorioDocumento repo) {
        this.repo = repo;
    }

    @Override
    public void excluir(int id, String ambiente) {
        repo.excluir(id, ambiente);
    }
}
