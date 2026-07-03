package com.prognum.scci.acesso.adaptadores.entrada;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.scci.acesso.dominio.model.ResultadoLogin;
import com.prognum.scci.acesso.dominio.model.ResultadoTroca;
import com.prognum.scci.acesso.dominio.port.in.LoginUseCase;
import com.prognum.scci.acesso.dominio.port.in.RecuperarSenhaUseCase;
import com.prognum.scci.acesso.dominio.port.in.TrocarSenhaUseCase;
import com.prognum.scci.acesso.dominio.port.in.ValidarAcessoUseCase;

/**
 * REST INTERNO do contexto acesso (consumido pelo launcher-edge quando a flag {@code acesso.*} aponta
 * JAVA/scci-core). NÃO faz W_COP — o edge decifra e manda TEXTO pela rede interna confiável. NÃO
 * registra sessão aqui (é do contexto {@code sessao}): devolve o resultado cru para o edge orquestrar.
 *
 * <ul>
 *   <li>POST {@code /interno/acesso/login}         — login (BANCO/família B) coordenado;</li>
 *   <li>POST {@code /interno/acesso/senha}         — troca de senha (/w/password);</li>
 *   <li>POST {@code /interno/acesso/email-pwd}     — recuperação por e-mail (/w/email-pwd);</li>
 *   <li>POST {@code /interno/acesso/valida-acesso} — ValidaCpf/ValidaProtocolo (/w/valida-acesso).</li>
 * </ul>
 */
@RestController
public class AcessoInternoController {

    private final LoginUseCase login;
    private final TrocarSenhaUseCase trocarSenha;
    private final RecuperarSenhaUseCase recuperarSenha;
    private final ValidarAcessoUseCase validarAcesso;

    public AcessoInternoController(LoginUseCase login, TrocarSenhaUseCase trocarSenha,
                                   RecuperarSenhaUseCase recuperarSenha, ValidarAcessoUseCase validarAcesso) {
        this.login = login;
        this.trocarSenha = trocarSenha;
        this.recuperarSenha = recuperarSenha;
        this.validarAcesso = validarAcesso;
    }

    @PostMapping("/interno/acesso/login")
    public ResponseEntity<ResultadoLogin> login(@RequestBody LoginRequest req) {
        return ResponseEntity.ok(login.login(req.usuario(), req.senha(), req.ambiente(), req.ip()));
    }

    @PostMapping("/interno/acesso/senha")
    public ResponseEntity<ResultadoTroca> senha(@RequestBody TrocaSenhaRequest req) {
        return ResponseEntity.ok(trocarSenha.trocar(req.usuario(), req.senhaAtual(), req.novaSenha(), req.ambiente()));
    }

    @PostMapping("/interno/acesso/email-pwd")
    public ResponseEntity<ResultadoTroca> emailPwd(@RequestBody RecuperacaoRequest req) {
        return ResponseEntity.ok(recuperarSenha.recuperar(req.usuario(), req.cpf(), req.ambiente()));
    }

    @PostMapping("/interno/acesso/valida-acesso")
    public ResponseEntity<ValidaResponse> validaAcesso(@RequestBody ValidaRequest req) {
        boolean valido = "protocolo".equalsIgnoreCase(req.tipo())
                ? validarAcesso.protocoloValido(req.valor(), req.ambiente())
                : validarAcesso.cpfValido(req.valor(), req.ambiente());
        return ResponseEntity.ok(new ValidaResponse(valido));
    }

    /** Corpos internos (texto; sem W_COP — o edge já decifrou). */
    public record LoginRequest(String usuario, String senha, String ambiente, String ip) {
    }

    public record TrocaSenhaRequest(String usuario, String senhaAtual, String novaSenha, String ambiente) {
    }

    public record RecuperacaoRequest(String usuario, String cpf, String ambiente) {
    }

    public record ValidaRequest(String tipo, String valor, String ambiente) {
    }

    public record ValidaResponse(boolean valido) {
    }
}
