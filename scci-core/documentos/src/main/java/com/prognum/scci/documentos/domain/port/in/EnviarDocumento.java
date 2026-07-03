package com.prognum.scci.documentos.domain.port.in;

/**
 * Casos de uso de UPLOAD (Post* do wdoc): anti-malware → conversão imagem→PDF (se aplicável) → gravação.
 * {@code enviar} = nova versão de um documento existente (id conhecido); {@code enviarParaPasta} =
 * PostDocumento (acha o doc {@code nome} na pasta {@code idPai} ou cria um novo nó no SISTARQ).
 */
public interface EnviarDocumento {

    /** Nova versão de documento existente (id). Devolve a versão gravada. */
    int enviar(int id, String nome, byte[] conteudo, String usuario, String ambiente);

    /** PostDocumento: upload para a pasta {@code idPai}. Devolve o ID do documento (novo ou existente). */
    int enviarParaPasta(int idPai, String nome, byte[] conteudo, String usuario, String ambiente);
}
