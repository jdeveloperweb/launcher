package com.prognum.scci.documentos.adapters.out;

import java.io.ByteArrayOutputStream;
import java.util.Locale;
import java.util.Set;

import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import com.lowagie.text.Document;
import com.lowagie.text.Image;
import com.lowagie.text.PageSize;
import com.lowagie.text.pdf.PdfWriter;
import com.prognum.scci.documentos.domain.port.out.ConversorImagemPdf;

/**
 * Conversão imagem→PDF em <b>lib Java pura</b> (openpdf) — reimplementa o {@code convert} (ImageMagick) do
 * wdoc/ARISP em Java, sem processo/binário externo (mantém o {@code scci-core} thin). Se o arquivo for
 * imagem, embrulha num PDF (uma página A4, imagem escalada); senão devolve o conteúdo original.
 * {@code @Primary} sobrepõe o hook no-op.
 */
@Component
@Primary
public class ConversorImagemPdfOpenPdf implements ConversorImagemPdf {

    private static final Set<String> IMAGENS = Set.of("jpg", "jpeg", "png", "gif", "bmp", "tif", "tiff");

    @Override
    public Resultado converter(byte[] conteudo, String nome) {
        if (!ehImagem(nome) || conteudo == null || conteudo.length == 0) {
            return new Resultado(conteudo, nome);
        }
        try {
            Document doc = new Document(PageSize.A4, 20, 20, 20, 20);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            PdfWriter.getInstance(doc, out);
            doc.open();
            Image img = Image.getInstance(conteudo);
            img.scaleToFit(PageSize.A4.getWidth() - 40, PageSize.A4.getHeight() - 40);
            doc.add(img);
            doc.close();
            return new Resultado(out.toByteArray(), trocaExtensaoParaPdf(nome));
        } catch (Exception e) {
            throw new IllegalStateException("falha ao converter imagem em PDF: " + nome, e);
        }
    }

    private static boolean ehImagem(String nome) {
        if (nome == null) {
            return false;
        }
        int p = nome.lastIndexOf('.');
        return p >= 0 && IMAGENS.contains(nome.substring(p + 1).toLowerCase(Locale.ROOT));
    }

    private static String trocaExtensaoParaPdf(String nome) {
        int p = nome.lastIndexOf('.');
        return (p < 0 ? nome : nome.substring(0, p)) + ".pdf";
    }
}
