package com.prognum.scci.documentos.adapters.out;

import org.springframework.stereotype.Component;

import com.prognum.scci.documentos.domain.port.out.ConversorImagemPdf;

/**
 * Impl default da conversão imagem→PDF: PASS-THROUGH (não converte) — placeholder até plugar o ImageMagick
 * real (o {@code /usr/bin/convert} que o wdoc/ARISP usa). Substituível por outro @Component (@Primary).
 */
@Component
public class ConversorImagemPdfNoop implements ConversorImagemPdf {

    @Override
    public Resultado converter(byte[] conteudo, String nome) {
        return new Resultado(conteudo, nome);
    }
}
