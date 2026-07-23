package com.prognum.launcher.compartilhado.web;

import com.prognum.launcher.autenticacao.port.out.SessaoAtiva;
import com.prognum.launcher.autenticacao.port.out.SessaoPersistente;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Admin/observabilidade (rede interna, atras do Kong): lista os usuarios conectados a um ambiente
 * (SCCI_SESSION), para o painel de sessoes do configurador. SOMENTE LEITURA. Nao exposto ao front.
 */
@RestController
public class AdminSessoesController {

    private final SessaoPersistente sessoes;

    public AdminSessoesController(SessaoPersistente sessoes) {
        this.sessoes = sessoes;
    }

    /** Sessoes ativas de um ambiente: {@code GET /admin/sessoes?ambiente=/u11/caixa/dados}. */
    @GetMapping("/admin/sessoes")
    public List<SessaoAtiva> sessoes(@RequestParam String ambiente) {
        return sessoes.listar(ambiente);
    }
}
