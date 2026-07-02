package com.prognum.scci.documentos.aplicacao;

import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService.DocumentoNaoEncontrado;
import com.prognum.scci.documentos.dominio.Documento;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumento;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumentoEntidade;
import com.prognum.scci.documentos.dominio.port.out.ResolvedorDocumento;

/**
 * Leitura por entidade (GetDocumentoOperacao/Sisat): resolve a entidade → id no SISTARQ (via
 * {@link ResolvedorDocumento}) e delega ao {@link BaixarDocumento} para transmitir o binário. POJO puro —
 * testável com fakes. Não resolvido vira {@link DocumentoNaoEncontrado} (o "Visualização não disponível").
 */
public class BaixarDocumentoEntidadeService implements BaixarDocumentoEntidade {

    private final ResolvedorDocumento resolvedor;
    private final BaixarDocumento baixar;

    public BaixarDocumentoEntidadeService(ResolvedorDocumento resolvedor, BaixarDocumento baixar) {
        this.resolvedor = resolvedor;
        this.baixar = baixar;
    }

    @Override
    public Documento porOperacao(String nuPretendente, String nuDocumento, boolean caseSensitive,
                                 boolean download, String ambiente) {
        int id = resolvedor.idPorOperacao(nuPretendente, nuDocumento, caseSensitive, ambiente)
                .orElseThrow(() -> new DocumentoNaoEncontrado(-1));
        return baixar.baixar(id, download, ambiente);
    }

    @Override
    public Documento porSisat(int nuOcorrencia, String nuDocumento, boolean download, String ambiente) {
        int id = resolvedor.idPorSisat(nuOcorrencia, nuDocumento, ambiente)
                .orElseThrow(() -> new DocumentoNaoEncontrado(-1));
        return baixar.baixar(id, download, ambiente);
    }
}
