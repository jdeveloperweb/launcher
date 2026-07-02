package com.prognum.scci.documentos.adaptadores.entrada;

import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService.DocumentoNaoEncontrado;
import com.prognum.scci.documentos.dominio.Documento;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumento;

/**
 * REST INTERNO do contexto documentos (consumido pelo launcher quando a flag do módulo aponta JAVA).
 * Idiomático em Java: devolve {@code byte[]} com {@code Content-Type} real + {@code Content-Disposition}
 * (attachment se download) — NÃO o framing Pascal {@code [len][XML]}. Não é exposto ao front (rede interna).
 */
@RestController
public class DocumentoInternoController {

    private final BaixarDocumento baixar;

    public DocumentoInternoController(BaixarDocumento baixar) {
        this.baixar = baixar;
    }

    @GetMapping("/interno/documentos/{id}")
    public ResponseEntity<byte[]> baixar(@PathVariable int id,
                                         @RequestParam String ambiente,
                                         @RequestParam(defaultValue = "false") boolean download) {
        Documento doc = baixar.baixar(id, download, ambiente);
        ContentDisposition cd = (download ? ContentDisposition.attachment() : ContentDisposition.inline())
                .filename(doc.nome()).build();
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(doc.tipoMime()))
                .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .body(doc.conteudo());
    }

    @org.springframework.web.bind.annotation.ExceptionHandler(DocumentoNaoEncontrado.class)
    public ResponseEntity<String> naoEncontrado(DocumentoNaoEncontrado e) {
        return ResponseEntity.status(404).body(e.getMessage());
    }
}
