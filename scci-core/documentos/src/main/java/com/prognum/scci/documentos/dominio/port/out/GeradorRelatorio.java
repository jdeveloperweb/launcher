package com.prognum.scci.documentos.dominio.port.out;

import java.util.Map;

/**
 * Gera um relatório PDF a partir de um template + dados JSON — reimplementação do {@code GeraJasper} do
 * wdoc em Java, usando a lib nativa JasperReports (o Jasper do legado já era Jasper; aqui roda dentro do
 * Java, sem processo/engine externo). Substitui o "fica em Pascal" da ADR-002 para relatórios Jasper.
 */
public interface GeradorRelatorio {

    /**
     * Compila o {@code jrxml}, preenche com o {@code jsonDados} (JsonDataSource) e exporta PDF.
     * {@code parametros} são os parâmetros do relatório (ex.: SUBREPORT_DIR).
     */
    byte[] gerarPdf(String jrxml, String jsonDados, Map<String, Object> parametros);
}
