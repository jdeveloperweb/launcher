package com.prognum.scci.documentos.adaptadores.entrada;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.scci.documentos.dominio.port.in.GerarRelatorioPdf;

/**
 * REST interno de RELATÓRIOS (GeraJasper do wdoc, agora em Java). Carrega o template {@code <nome>.jrxml}
 * do diretório configurado ({@code scci.documentos.jasper-dir}), preenche com o JSON do corpo e devolve o
 * PDF. {@code SUBREPORT_DIR} aponta o mesmo diretório (para os subreports {@code .jasper}).
 */
@RestController
public class RelatorioInternoController {

    private final GerarRelatorioPdf gerar;
    private final String jasperDir;

    public RelatorioInternoController(GerarRelatorioPdf gerar,
                                      @Value("${scci.documentos.jasper-dir:./relatorios}") String jasperDir) {
        this.gerar = gerar;
        this.jasperDir = jasperDir;
    }

    @PostMapping("/interno/relatorios/{nome}/pdf")
    public ResponseEntity<byte[]> pdf(@PathVariable String nome, @RequestBody(required = false) byte[] json)
            throws Exception {
        String jrxml = Files.readString(Path.of(jasperDir, nome + ".jrxml"), StandardCharsets.UTF_8);
        String dados = json == null ? "{}" : new String(json, StandardCharsets.UTF_8);
        byte[] pdf = gerar.gerar(jrxml, dados, Map.of("SUBREPORT_DIR", jasperDir + "/"));
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header("Content-Disposition", "inline; filename=\"" + nome + ".pdf\"")
                .body(pdf);
    }
}
