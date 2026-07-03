package com.prognum.scci.acesso.application.mapeado;

import java.util.function.Supplier;

import com.prognum.scci.acesso.domain.mapeado.DadosProvisao;
import com.prognum.scci.acesso.domain.model.ResultadoLogin;
import com.prognum.scci.acesso.domain.port.out.Autenticador;

/**
 * Strategy de autenticação para a família "payload-mapeado" (itau/c6/brb/cashmeweb/direto/unicred/
 * ailos): o IdP externo já autenticou o usuário e mandou os atributos cifrados; aqui NÃO se verifica
 * senha — provisiona-se o USUARIO conforme os atributos e emite-se a sessão.
 *
 * Concentra o COMUM a todos: gerar o token da sessão, delegar o provisionamento à {@link EstrategiaProvisao}
 * do cliente e montar o {@link ResultadoLogin}. Erro de provisionamento (usuário sem acesso, perfil
 * inexistente…) vira código 'F' com a mensagem do legado — o coordenador {@code LoginService} então
 * aplica o comum (tentativas/captcha). O token emitido aqui é preservado pelo coordenador. POJO puro.
 */
public class AutenticadorMapeado implements Autenticador {

    private final String metodo;
    private final EstrategiaProvisao estrategia;
    private final Supplier<String> geradorToken;

    public AutenticadorMapeado(EstrategiaProvisao estrategia, Supplier<String> geradorToken) {
        this.metodo = estrategia.metodo();
        this.estrategia = estrategia;
        this.geradorToken = geradorToken;
    }

    @Override
    public String metodo() {
        return metodo;
    }

    @Override
    public ResultadoLogin autenticar(String usuario, String segredo, String ambiente, String ip) {
        try {
            String token = geradorToken.get();
            DadosProvisao d = estrategia.provisiona(usuario, segredo, ambiente, ip, token);
            return new ResultadoLogin(true, 'T', d.sessionToken(), "OK", null, d.usuarioEfetivo());
        } catch (RuntimeException e) {
            // fiel ao legado: qualquer falha no ExecutaLoginXXX vira 'F'+mensagem
            String msg = e.getMessage() == null ? "Falha na autenticacao." : e.getMessage();
            return new ResultadoLogin(false, 'F', null, msg, null);
        }
    }
}
