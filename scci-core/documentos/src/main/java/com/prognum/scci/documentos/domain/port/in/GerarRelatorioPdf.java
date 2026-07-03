package com.prognum.scci.documentos.domain.port.in;

import java.util.Map;

/** Caso de uso: gerar relatório PDF (GeraJasper do wdoc) a partir de um template .jrxml + dados JSON. */
public interface GerarRelatorioPdf {

    byte[] gerar(String jrxml, String jsonDados, Map<String, Object> parametros);
}
