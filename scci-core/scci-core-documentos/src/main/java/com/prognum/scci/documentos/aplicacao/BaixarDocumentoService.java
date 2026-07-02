package com.prognum.scci.documentos.aplicacao;

import java.util.Optional;

import com.prognum.scci.documentos.dominio.ArquivoBruto;
import com.prognum.scci.documentos.dominio.Documento;
import com.prognum.scci.documentos.dominio.TipoMime;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumento;
import com.prognum.scci.documentos.dominio.port.out.RepositorioDocumento;

/**
 * Casos de uso de leitura de documento (porte idiomático do GetDocumento / GetDocumentoVersao /
 * GetDocumentoContratoAssinatura). Busca no storage, deriva o content-type da extensão e monta o
 * {@link Documento}. POJO puro — testável com fake. Inexistente vira {@link DocumentoNaoEncontrado}
 * (o "Visualização não disponível" do apilib, como exceção de domínio).
 */
public class BaixarDocumentoService implements BaixarDocumento {

    private final RepositorioDocumento repo;

    public BaixarDocumentoService(RepositorioDocumento repo) {
        this.repo = repo;
    }

    @Override
    public Documento baixar(int id, boolean download, String ambiente) {
        return montar(repo.buscarUltimaVersao(id, ambiente), id, download);
    }

    @Override
    public Documento baixarVersao(int id, int versao, boolean download, String ambiente) {
        return montar(repo.buscarVersao(id, versao, ambiente), id, download);
    }

    private static Documento montar(Optional<ArquivoBruto> achado, int id, boolean download) {
        ArquivoBruto arq = achado.orElseThrow(() -> new DocumentoNaoEncontrado(id));
        return new Documento(arq.nome(), TipoMime.doNome(arq.nome()), arq.conteudo(), download);
    }

    /** Documento não existe (o "Visualização não disponível" do wdoc). */
    public static class DocumentoNaoEncontrado extends RuntimeException {
        public DocumentoNaoEncontrado(int id) {
            super("Documento nao encontrado: " + id);
        }
    }
}
