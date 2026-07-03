package com.prognum.scci.documentos.application;

import com.prognum.scci.documentos.domain.port.in.EnviarDocumento;
import com.prognum.scci.documentos.domain.port.out.AntiMalware;
import com.prognum.scci.documentos.domain.port.out.ArmazenadorDocumento;
import com.prognum.scci.documentos.domain.port.out.ConversorImagemPdf;

/**
 * Upload de documento (porte do fluxo Post* do wdoc): anti-malware → conversão imagem→PDF (se aplicável)
 * → gravação da nova versão no SISTARQ. Orquestra os ports; POJO puro, testável com fakes.
 */
public class EnviarDocumentoService implements EnviarDocumento {

    private final AntiMalware antiMalware;
    private final ConversorImagemPdf conversor;
    private final ArmazenadorDocumento armazenador;

    public EnviarDocumentoService(AntiMalware antiMalware, ConversorImagemPdf conversor,
                                  ArmazenadorDocumento armazenador) {
        this.antiMalware = antiMalware;
        this.conversor = conversor;
        this.armazenador = armazenador;
    }

    @Override
    public int enviar(int id, String nome, byte[] conteudo, String usuario, String ambiente) {
        ConversorImagemPdf.Resultado r = verificarEConverter(conteudo, nome);
        return armazenador.gravarVersao(id, r.nome(), r.conteudo(), usuario, ambiente);
    }

    @Override
    public int enviarParaPasta(int idPai, String nome, byte[] conteudo, String usuario, String ambiente) {
        ConversorImagemPdf.Resultado r = verificarEConverter(conteudo, nome);
        return armazenador.inserirArquivoVersao(idPai, r.nome(), r.conteudo(), usuario, ambiente);
    }

    private ConversorImagemPdf.Resultado verificarEConverter(byte[] conteudo, String nome) {
        antiMalware.verificar(conteudo, nome);                              // reprova => exceção
        return conversor.converter(conteudo, nome);
    }
}
