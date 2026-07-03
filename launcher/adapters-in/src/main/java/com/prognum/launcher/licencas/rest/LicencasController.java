package com.prognum.launcher.licencas.rest;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * SCAFFOLD do bounded context LICENCAS. Sem regra de negocio definida — responde 501
 * (Not Implemented). Quando a regra for especificada, ligar a um ConsultarLicencasUseCase.
 */
@RestController
@RequestMapping("/licencas")
public class LicencasController {

    @GetMapping
    public ResponseEntity<String> listar() {
        return ResponseEntity.status(HttpStatus.NOT_IMPLEMENTED)
                .body("{\"success\":false,\"message\":\"Contexto 'licencas' ainda nao implementado (regra a definir).\"}");
    }
}
