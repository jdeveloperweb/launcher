package com.prognum.scci.documentos.adaptadores.entrada;

import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService.DocumentoNaoEncontrado;
import com.prognum.scci.documentos.dominio.Documento;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumento;
import com.prognum.scci.documentos.dominio.port.in.ExcluirDocumento;

/**
 * REST INTERNO do contexto documentos (consumido pelo launcher quando a flag do módulo aponta JAVA). Cobre
 * a família de leitura/exclusão do wdoc que é id-direta (a resolução por operação/sisat, que depende do
 * apilib, entra depois). Idiomático: {@code byte[]} + {@code Content-Type} + {@code Content-Disposition}
 * reais — NÃO o framing Pascal {@code [len][XML]}. Não exposto ao front (rede interna).
 *
 * <ul>
 *   <li>GET  {@code /interno/documentos/{id}}                — GetDocumento (e GetDocumentoContratoAssinatura com {@code download=true});</li>
 *   <li>GET  {@code /interno/documentos/{id}/versoes/{v}}    — GetDocumentoVersao;</li>
 *   <li>DELETE {@code /interno/documentos/{id}}              — DeleteDocumento.</li>
 * </ul>
 */
@RestController
public class DocumentoInternoController {

    private final BaixarDocumento baixar;
    private final ExcluirDocumento excluir;

    public DocumentoInternoController(BaixarDocumento baixar, ExcluirDocumento excluir) {
        this.baixar = baixar;
        this.excluir = excluir;
    }

    @GetMapping("/interno/documentos/{id}")
    public ResponseEntity<byte[]> baixar(@PathVariable int id,
                                         @RequestParam String ambiente,
                                         @RequestParam(defaultValue = "false") boolean download) {
        return resposta(baixar.baixar(id, download, ambiente));
    }

    @GetMapping("/interno/documentos/{id}/versoes/{versao}")
    public ResponseEntity<byte[]> baixarVersao(@PathVariable int id,
                                               @PathVariable int versao,
                                               @RequestParam String ambiente,
                                               @RequestParam(defaultValue = "false") boolean download) {
        return resposta(baixar.baixarVersao(id, versao, download, ambiente));
    }

    @DeleteMapping("/interno/documentos/{id}")
    public ResponseEntity<Void> excluir(@PathVariable int id, @RequestParam String ambiente) {
        excluir.excluir(id, ambiente);
        return ResponseEntity.noContent().build();
    }

    private static ResponseEntity<byte[]> resposta(Documento doc) {
        ContentDisposition cd = (doc.download() ? ContentDisposition.attachment() : ContentDisposition.inline())
                .filename(doc.nome()).build();
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(doc.tipoMime()))
                .header(HttpHeaders.CONTENT_DISPOSITION, cd.toString())
                .body(doc.conteudo());
    }

    @ExceptionHandler(DocumentoNaoEncontrado.class)
    public ResponseEntity<String> naoEncontrado(DocumentoNaoEncontrado e) {
        return ResponseEntity.status(404).body(e.getMessage());
    }
}
