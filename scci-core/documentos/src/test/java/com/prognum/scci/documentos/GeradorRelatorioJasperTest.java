package com.prognum.scci.documentos;

import java.nio.charset.StandardCharsets;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.prognum.scci.documentos.adaptadores.saida.GeradorRelatorioJasper;

import static org.assertj.core.api.Assertions.assertThat;

/** Gera PDF de verdade com JasperReports (lib Java) a partir de um .jrxml + JSON. */
class GeradorRelatorioJasperTest {

    private static final String JRXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <jasperReport xmlns="http://jasperreports.sourceforge.net/jasperreports"
                name="teste" pageWidth="595" pageHeight="842" columnWidth="555"
                leftMargin="20" rightMargin="20" topMargin="20" bottomMargin="20">
              <queryString language="json"><![CDATA[itens]]></queryString>
              <field name="nome" class="java.lang.String"><fieldDescription><![CDATA[nome]]></fieldDescription></field>
              <detail>
                <band height="20">
                  <textField>
                    <reportElement x="0" y="0" width="500" height="18"/>
                    <textFieldExpression><![CDATA[$F{nome}]]></textFieldExpression>
                  </textField>
                </band>
              </detail>
            </jasperReport>
            """;

    @Test
    void gera_pdf_a_partir_de_jrxml_e_json() {
        String json = "{\"itens\":[{\"nome\":\"Documento A\"},{\"nome\":\"Documento B\"}]}";

        byte[] pdf = new GeradorRelatorioJasper().gerarPdf(JRXML, json, Map.of());

        assertThat(pdf).isNotEmpty();
        String cabecalho = new String(pdf, 0, Math.min(5, pdf.length), StandardCharsets.ISO_8859_1);
        assertThat(cabecalho).startsWith("%PDF");     // é um PDF de verdade
    }
}
