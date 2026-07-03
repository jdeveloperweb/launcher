package com.prognum.scci.documentos.adaptadores.saida;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

import org.springframework.stereotype.Component;

import com.prognum.scci.documentos.dominio.port.out.GeradorRelatorio;

import net.sf.jasperreports.engine.JasperCompileManager;
import net.sf.jasperreports.engine.JasperExportManager;
import net.sf.jasperreports.engine.JasperFillManager;
import net.sf.jasperreports.engine.JasperPrint;
import net.sf.jasperreports.engine.JasperReport;
import net.sf.jasperreports.engine.query.JsonQueryExecuterFactory;

/**
 * Gera relatório PDF com <b>JasperReports</b> (lib Java nativa) — reimplementação do GeraJasper do wdoc,
 * dentro do Java, sem engine/processo externo. Compila o {@code .jrxml}, roda a {@code <queryString
 * language="json">} do template sobre o JSON de dados (JsonQueryExecuter) e exporta PDF.
 *
 * Subreports (ex.: {@code sub_itens_inter.jasper}) precisam estar compilados no diretório apontado por
 * {@code SUBREPORT_DIR} (parâmetro do relatório) — passado em {@code parametros}.
 */
@Component
public class GeradorRelatorioJasper implements GeradorRelatorio {

    @Override
    public byte[] gerarPdf(String jrxml, String jsonDados, Map<String, Object> parametros) {
        try {
            JasperReport relatorio = JasperCompileManager.compileReport(
                    new ByteArrayInputStream(jrxml.getBytes(StandardCharsets.UTF_8)));

            Map<String, Object> params = new HashMap<>();
            if (parametros != null) {
                params.putAll(parametros);
            }
            // fonte JSON via query executer: usa o <queryString language="json"> do próprio template
            params.put(JsonQueryExecuterFactory.JSON_INPUT_STREAM,
                    new ByteArrayInputStream((jsonDados == null ? "{}" : jsonDados).getBytes(StandardCharsets.UTF_8)));

            JasperPrint print = JasperFillManager.fillReport(relatorio, params);
            return JasperExportManager.exportReportToPdf(print);
        } catch (Exception e) {
            throw new IllegalStateException("falha ao gerar relatorio Jasper", e);
        }
    }
}
