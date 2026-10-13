package com.prognum.gateway.execucao.rest;

import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/** Evidência dos helpers do despacho /w: params da querystring completam o corpo do POST (abrir tela). */
class DespachoControllerTest {

    // o que o front manda ao abrir tela por POST: corpo "dados=" e o resto na querystring
    private static final String QUERY_ABRIR_TELA = "=&tela=formFinanciamento&sessionKey=ABC123"
            + "&contexto=CORP_WEB&userName=supervisor&ambienteOperacional=%2Fcdhu-launcher-java";

    @Test
    void querystring_do_front_ignora_a_chave_vazia_inicial_e_decodifica() {
        Map<String, String> q = DespachoController.camposDoForm(QUERY_ABRIR_TELA);
        assertThat(q).containsEntry("tela", "formFinanciamento")
                .containsEntry("sessionKey", "ABC123")
                .containsEntry("userName", "supervisor")
                .containsEntry("ambienteOperacional", "/cdhu-launcher-java")
                .doesNotContainKey("");
    }

    @Test
    void querystring_ausente_nao_traz_nada() {
        assertThat(DespachoController.camposDoForm(null)).isEmpty();
        assertThat(DespachoController.camposDoForm("")).isEmpty();
    }

    @Test
    void post_de_abrir_tela_recebe_da_query_o_que_nao_veio_no_corpo() {
        Map<String, String> corpo = DespachoController.camposDoForm("dados=");
        Map<String, String> extras = DespachoController.soNaQuery(corpo,
                DespachoController.camposDoForm(QUERY_ABRIR_TELA));
        assertThat(extras).containsOnlyKeys("tela", "sessionKey", "contexto", "userName", "ambienteOperacional");
    }

    @Test
    void corpo_manda_sobre_a_query_mesmo_vazio() {
        Map<String, String> corpo = new LinkedHashMap<>();
        corpo.put("tela", "telaDoCorpo");
        corpo.put("dados", "");
        Map<String, String> extras = DespachoController.soNaQuery(corpo,
                DespachoController.camposDoForm("tela=telaDaQuery&dados=x&sessionKey=ABC123"));
        assertThat(extras).containsOnlyKeys("sessionKey");
    }
}
