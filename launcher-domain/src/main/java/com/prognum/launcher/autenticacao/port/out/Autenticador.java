package com.prognum.launcher.autenticacao.port.out;

import com.prognum.launcher.autenticacao.model.ResultadoLogin;

/**
 * Strategy de AUTENTICAÇÃO — um por mecanismo do SCCI (os loginXXX.pas): BANCO (loginbd, md5crypt),
 * OAUTH (loginc6/itau/…), API_EXTERNA (loginsicredi/sicoob/…), LDAP (loginad). Cada cliente usa o
 * método definido na sua CONFIGURAÇÃO (ver {@link MetodoLoginResolver}), então portar um cliente novo
 * do mesmo tipo é só configuração.
 *
 * Responsabilidade: SÓ verificar a credencial e devolver o resultado (código de estado). O que é
 * COMUM a todos — bloqueio por tentativas, captcha, emissão de sessionKey, log — fica no coordenador
 * ({@code LoginService}). Por isso o {@link ResultadoLogin} devolvido vem com {@code sessionKey=null}:
 * quem emite o token é o coordenador, no sucesso.
 *
 * Códigos ({@code codErro}) que o coordenador interpreta: 'F'=credencial inválida (conta tentativa),
 * 'E'=expirada, 'M'=troca obrigatória, 'C'=vai expirar (sucesso c/ aviso), 'T'=ok.
 */
public interface Autenticador {

    /** Id do método (ex.: "BANCO", "OAUTH", "LDAP", "API_SICREDI"). Casa com {@link MetodoLoginResolver}. */
    String metodo();

    /**
     * Verifica a credencial do usuário no ambiente. {@code segredo} = senha (BANCO/LDAP) ou token
     * (OAUTH) ou o que o mecanismo esperar. NÃO emite sessionKey (o coordenador emite no sucesso).
     */
    ResultadoLogin autenticar(String usuario, String segredo, String ambiente, String ip);
}
