package com.prognum.gateway.documentos.rest;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * SCAFFOLD do bounded context DOCUMENTOS. Sem regra de negocio definida — responde 501
 * (Not Implemented). Quando a regra for especificada, ligar a um ConsultarDocumentosUseCase.
 */
@RestController
@RequestMapping("/documentos")
public class DocumentosController {

    @GetMapping
    public ResponseEntity<String> listar() {
        return ResponseEntity.status(HttpStatus.NOT_IMPLEMENTED)
                .body("{\"success\":false,\"message\":\"Contexto 'documentos' ainda nao implementado (regra a definir).\"}");
    }
}
