package com.prognum.launcher.legacy.proxy;

import com.prognum.launcher.api.dto.ExecuteRequest;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.net.URI;
import java.util.Enumeration;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Rota C (regras.md DA06/RF06): proxy HTTP para o W_COP.
 *
 * Dois modos:
 *  - proxy(ExecuteRequest): chamada estruturada (a partir de /v1/launcher/execute).
 *  - forward(HttpServletRequest, body): proxy TRANSPARENTE para o front legado
 *    (preserva metodo, caminho, query, corpo e content-type), devolvendo a
 *    resposta crua do W_COP. Usado pelo catch-all /** (compat com /aejs-l/rest/...).
 *
 * Em "simulacao" a base-url aponta para o simulador embutido. Para usar o W_COP
 * real, troque 'launcher.legacy.wcop.base-url' (e desligue o simulador).
 */
@Component
public class LegacyProxyClient {

    /** Headers que NAO devem ser repassados (hop-by-hop / recalculados pelo cliente). */
    private static final Set<String> HOP_BY_HOP = Set.of(
            "host", "connection", "content-length", "transfer-encoding", "keep-alive",
            "proxy-authenticate", "proxy-authorization", "te", "trailer", "upgrade", "accept-encoding");

    private final RestClient http;
    private final String baseUrl;
    private final String pathTemplate;

    public LegacyProxyClient(
            RestClient http,
            @Value("${launcher.legacy.wcop.base-url}") String baseUrl,
            @Value("${launcher.legacy.wcop.path-template:/{programa}/{metodo}}") String pathTemplate) {
        this.http = http;
        this.baseUrl = baseUrl;
        this.pathTemplate = pathTemplate;
    }

    /** Chamada estruturada (corpo = params em JSON). */
    public Object proxy(ExecuteRequest req) {
        String path = pathTemplate
                .replace("{programa}", nz(req.programa()))
                .replace("{metodo}", nz(req.metodo()));
        Object body = (req.params() == null) ? Map.of() : req.params();
        return http.post()
                .uri(baseUrl + path)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(Object.class);
    }

    /**
     * Proxy transparente: repassa a requisicao original (metodo, caminho, query,
     * corpo, content-type) para o W_COP e devolve a resposta crua (status + corpo).
     * 'subPath' e o caminho a anexar na base-url (ex.: "/w/login").
     */
    public ResponseEntity<byte[]> forward(HttpServletRequest req, byte[] body, String subPath) {
        String target = baseUrl + subPath;
        String qs = req.getQueryString();
        if (qs != null && !qs.isBlank()) {
            target = target + "?" + qs;                 // preserva a query (ex.: sessionKey, contexto, ambienteOperacional)
        }

        RestClient.RequestBodySpec spec = http
                .method(HttpMethod.valueOf(req.getMethod()))
                .uri(URI.create(target));

        // Marca a chamada como originada do gateway (a guarda anti-recursao do catch-all confia nisso).
        spec.header("X-Gateway-Forwarded", "1");

        // Repassa os headers do front (menos hop-by-hop): Authorization, Cookie, Content-Type, etc.
        Enumeration<String> names = req.getHeaderNames();
        if (names != null) {
            while (names.hasMoreElements()) {
                String name = names.nextElement();
                if (HOP_BY_HOP.contains(name.toLowerCase())) {
                    continue;
                }
                Enumeration<String> values = req.getHeaders(name);
                while (values.hasMoreElements()) {
                    spec.header(name, values.nextElement());
                }
            }
        }

        RestClient.ResponseSpec rs = (body != null && body.length > 0)
                ? spec.body(body).retrieve()
                : spec.retrieve();

        ResponseEntity<byte[]> resp = rs
                .onStatus(s -> true, (rq, rp) -> { })   // nao lanca em 4xx/5xx: repassa como veio
                .toEntity(byte[].class);

        // Devolve status + corpo cru, preservando Content-Type e Set-Cookie do W_COP.
        HttpHeaders out = new HttpHeaders();
        MediaType respCt = resp.getHeaders().getContentType();
        out.setContentType(respCt != null ? respCt : MediaType.APPLICATION_OCTET_STREAM);
        List<String> cookies = resp.getHeaders().get(HttpHeaders.SET_COOKIE);
        if (cookies != null) {
            cookies.forEach(c -> out.add(HttpHeaders.SET_COOKIE, c));
        }
        return new ResponseEntity<>(resp.getBody(), out, resp.getStatusCode());
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }
}
