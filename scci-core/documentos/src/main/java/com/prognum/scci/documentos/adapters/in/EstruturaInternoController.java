package com.prognum.scci.documentos.adapters.in;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.scci.documentos.domain.port.in.GerenciarEstrutura;

/** REST interno de estrutura de documentos (PutNome/PutPasta do wdoc): renomear e criar pasta. */
@RestController
public class EstruturaInternoController {

    private final GerenciarEstrutura estrutura;

    public EstruturaInternoController(GerenciarEstrutura estrutura) {
        this.estrutura = estrutura;
    }

    /** PutNome. */
    @PutMapping("/interno/documentos/{id}/nome")
    public ResponseEntity<String> renomear(@PathVariable int id,
                                           @RequestParam String novoNome,
                                           @RequestParam String ambiente) {
        estrutura.renomear(id, novoNome, ambiente);
        return ResponseEntity.ok("{\"success\":true}");
    }

    /** PutPasta. */
    @PostMapping("/interno/documentos/pastas")
    public ResponseEntity<String> criarPasta(@RequestParam int idPai,
                                             @RequestParam String nome,
                                             @RequestParam String ambiente,
                                             @RequestParam(defaultValue = "true") boolean exibePastas) {
        int id = estrutura.criarPasta(idPai, nome, exibePastas, ambiente);
        return ResponseEntity.ok("{\"success\":true,\"dados\":{\"id\":" + id + "}}");
    }
}
