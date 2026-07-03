package com.prognum.launcher.autenticacao.scci;

import java.util.Map;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import com.fasterxml.jackson.databind.JsonNode;
import com.prognum.launcher.autenticacao.model.ResultadoLogin;
import com.prognum.launcher.autenticacao.model.ResultadoTroca;
import com.prognum.launcher.autenticacao.port.out.AcessoJavaPort;

/**
 * Cliente do REST interno do <b>scci-core/acesso</b> — o caminho JAVA/remoto dos roteadores de auth.
 * Mapeia cada use case (login/senha/email-pwd/valida) para o endpoint interno, chama o scci-core e
 * converte a resposta JSON de volta nos tipos de domínio do launcher.
 *
 * Resiliência (igual ao {@code ClienteScciCoreDocumentos}): devolve {@link Optional#empty()} quando o
 * scci-core está inacessível/erro de transporte (→ fallback para o auth local). Uma resposta de NEGÓCIO
 * (login negado, etc.) volta preenchida — não faz fallback.
 */
@Component
public class ClienteScciCoreAcesso implements AcessoJavaPort {

    private static final Logger log = LoggerFactory.getLogger(ClienteScciCoreAcesso.class);

    private final RestClient rest;

    public ClienteScciCoreAcesso(@Value("${launcher.scci-core.url:http://localhost:8090}") String baseUrl) {
        this.rest = RestClient.builder().baseUrl(baseUrl).build();
    }

    @Override
    public Optional<ResultadoLogin> login(String usuario, String senha, String ambiente, String ip) {
        return chamar("/interno/acesso/login",
                Map.of("usuario", nz(usuario), "senha", nz(senha), "ambiente", nz(ambiente), "ip", nz(ip)),
                ClienteScciCoreAcesso::paraResultadoLogin, "login");
    }

    @Override
    public Optional<ResultadoTroca> trocarSenha(String usuario, String senhaAtual, String novaSenha, String ambiente) {
        return chamar("/interno/acesso/senha",
                Map.of("usuario", nz(usuario), "senhaAtual", nz(senhaAtual),
                        "novaSenha", nz(novaSenha), "ambiente", nz(ambiente)),
                ClienteScciCoreAcesso::paraResultadoTroca, "senha");
    }

    @Override
    public Optional<ResultadoTroca> recuperar(String usuario, String cpf, String ambiente) {
        return chamar("/interno/acesso/email-pwd",
                Map.of("usuario", nz(usuario), "cpf", nz(cpf), "ambiente", nz(ambiente)),
                ClienteScciCoreAcesso::paraResultadoTroca, "email-pwd");
    }

    @Override
    public Optional<Boolean> validarCpf(String valor, String ambiente) {
        return validar("cpf", valor, ambiente);
    }

    @Override
    public Optional<Boolean> validarProtocolo(String valor, String ambiente) {
        return validar("protocolo", valor, ambiente);
    }

    private Optional<Boolean> validar(String tipo, String valor, String ambiente) {
        return chamar("/interno/acesso/valida-acesso",
                Map.of("tipo", tipo, "valor", nz(valor), "ambiente", nz(ambiente)),
                n -> n.path("valido").asBoolean(false), "valida-" + tipo);
    }

    /** POST no scci-core; mapeia o corpo; empty em falha de transporte (→ fallback local). */
    private <T> Optional<T> chamar(String uri, Map<String, String> corpo,
                                   java.util.function.Function<JsonNode, T> mapear, String metodo) {
        try {
            JsonNode n = rest.post().uri(uri).body(corpo).retrieve().body(JsonNode.class);
            return n == null ? Optional.empty() : Optional.of(mapear.apply(n));
        } catch (RuntimeException e) {
            log.warn("scci_core_acesso_indisponivel metodo={} erro={} -> fallback local",
                    metodo, String.valueOf(e.getMessage()));
            return Optional.empty();
        }
    }

    private static ResultadoLogin paraResultadoLogin(JsonNode n) {
        String cod = n.path("codErro").asText("");
        Integer dias = n.hasNonNull("diasRestantes") ? n.get("diasRestantes").asInt() : null;
        return new ResultadoLogin(
                n.path("sucesso").asBoolean(false),
                cod.isEmpty() ? ' ' : cod.charAt(0),
                textoOuNull(n, "sessionKey"),
                n.path("mensagem").asText(""),
                dias,
                textoOuNull(n, "usuarioEfetivo"));
    }

    private static ResultadoTroca paraResultadoTroca(JsonNode n) {
        return new ResultadoTroca(n.path("sucesso").asBoolean(false), n.path("mensagem").asText(""));
    }

    private static String textoOuNull(JsonNode n, String campo) {
        return n.hasNonNull(campo) ? n.get(campo).asText() : null;
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }
}
