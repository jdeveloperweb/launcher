package com.prognum.scci.documentos.application;

import java.util.Map;

import com.prognum.scci.documentos.domain.port.in.GerarRelatorioPdf;
import com.prognum.scci.documentos.domain.port.out.GeradorRelatorio;

/** Geração de relatório PDF (GeraJasper): delega ao {@link GeradorRelatorio} (JasperReports). POJO puro. */
public class GerarRelatorioService implements GerarRelatorioPdf {

    private final GeradorRelatorio gerador;

    public GerarRelatorioService(GeradorRelatorio gerador) {
        this.gerador = gerador;
    }

    @Override
    public byte[] gerar(String jrxml, String jsonDados, Map<String, Object> parametros) {
        return gerador.gerarPdf(jrxml, jsonDados, parametros);
    }
}
