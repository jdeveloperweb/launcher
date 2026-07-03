package com.prognum.scci.documentos.aplicacao;

import com.prognum.scci.documentos.dominio.port.in.ExcluirDocumento;
import com.prognum.scci.documentos.dominio.port.out.RepositorioDocumento;

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
