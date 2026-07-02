package com.prognum.scci.documentos.dominio.port.in;

/**
 * Caso de uso de UPLOAD (Post* do wdoc): recebe o arquivo de uma nova versão de um documento existente,
 * passa por anti-malware e (se imagem) conversão para PDF, e grava a versão no SISTARQ. Devolve a versão
 * gravada. Escopo: documento já existente (id conhecido/resolvido); criação de documento novo é follow-up.
 */
public interface EnviarDocumento {

    int enviar(int id, String nome, byte[] conteudo, String usuario, String ambiente);
}
