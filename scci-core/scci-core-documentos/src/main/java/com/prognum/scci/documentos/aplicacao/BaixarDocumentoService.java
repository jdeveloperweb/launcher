package com.prognum.scci.documentos.aplicacao;

import com.prognum.scci.documentos.dominio.ArquivoBruto;
import com.prognum.scci.documentos.dominio.Documento;
import com.prognum.scci.documentos.dominio.TipoMime;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumento;
import com.prognum.scci.documentos.dominio.port.out.RepositorioDocumento;

/**
 * Caso de uso de download/visualização de documento (porte idiomático do GetDocumentoPorId). Busca a
 * última versão no storage, deriva o content-type da extensão e monta o {@link Documento}. POJO puro —
 * testável com um fake do {@link RepositorioDocumento}. Documento inexistente vira {@link DocumentoNaoEncontrado}
 * (fiel ao "Visualização não disponível" do apilib, mas como exceção de domínio).
 */
public class BaixarDocumentoService implements BaixarDocumento {

    private final RepositorioDocumento repo;

    public BaixarDocumentoService(RepositorioDocumento repo) {
        this.repo = repo;
    }

    @Override
    public Documento baixar(int id, boolean download, String ambiente) {
        ArquivoBruto arq = repo.buscarUltimaVersao(id, ambiente)
                .orElseThrow(() -> new DocumentoNaoEncontrado(id));
        return new Documento(arq.nome(), TipoMime.doNome(arq.nome()), arq.conteudo(), download);
    }

    /** Documento não existe (o "Visualização não disponível" do wdoc). */
    public static class DocumentoNaoEncontrado extends RuntimeException {
        public DocumentoNaoEncontrado(int id) {
            super("Documento nao encontrado: " + id);
        }
    }
}
