package com.prognum.scci.documentos.domain.port.out;

import java.util.Optional;

/**
 * Resolve a ENTIDADE de negócio (operação/pretendente, ocorrência SISAT) para o id do documento no
 * SISTARQ — porte de ObtemIDS/ObtemIDSTarefa do apilib (via GetNoDucumentoSistArq + GeraIDPaiDocumentos*
 * + LeIDDoPath, a caminhada na árvore de pastas do SISTARQ). Vazio quando não resolve.
 */
public interface ResolvedorDocumento {

    /** GetDocumentoOperacao/…Assinatura: (NU_PRETENDENTE, NU_DOCUMENTO) → id no SISTARQ. */
    Optional<Integer> idPorOperacao(String nuPretendente, String nuDocumento, boolean caseSensitive, String ambiente);

    /** GetDocumentoSisat: (NU_OCORRENCIA, NU_DOCUMENTO) → id no SISTARQ. */
    Optional<Integer> idPorSisat(int nuOcorrencia, String nuDocumento, String ambiente);
}
