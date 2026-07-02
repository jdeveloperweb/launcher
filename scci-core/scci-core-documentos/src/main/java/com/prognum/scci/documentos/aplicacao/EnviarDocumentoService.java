package com.prognum.scci.documentos.aplicacao;

import com.prognum.scci.documentos.dominio.port.in.EnviarDocumento;
import com.prognum.scci.documentos.dominio.port.out.AntiMalware;
import com.prognum.scci.documentos.dominio.port.out.ArmazenadorDocumento;
import com.prognum.scci.documentos.dominio.port.out.ConversorImagemPdf;

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
        antiMalware.verificar(conteudo, nome);                              // reprova => exceção
        ConversorImagemPdf.Resultado r = conversor.converter(conteudo, nome);
        return armazenador.gravarVersao(id, r.nome(), r.conteudo(), usuario, ambiente);
    }
}
