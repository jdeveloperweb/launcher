package com.prognum.gateway.execucao.rest;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.prognum.gateway.autenticacao.model.Sessao;
import com.prognum.gateway.autenticacao.port.in.SessaoUseCase;
import com.prognum.common.crypto.LogAnonimizador;
import com.prognum.common.crypto.WcopCrypto;
import com.prognum.common.environment.ResolvedorAmbiente;
import com.prognum.gateway.compartilhado.RespostaCharset;
import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;
import com.prognum.gateway.execucao.port.in.DespachoUseCase;
import com.prognum.gateway.execucao.port.out.RotaExecucaoRegistry;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Adapter de entrada do dominio EXECUCAO — reproduz FIEL o despacho /w do AejsWebController do
 * launcher SCCI (legado). O launcher recebe /w, VALIDA a sessao e EXECUTA o programa real (wmenu/wtela).
 * NENHUMA logica de programa aqui — so orquestracao (decifra -> valida sessao -> executa -> cifra).
 */
@Tag(name = "Despacho", description = "Execução genérica de programas Pascal (wmenu/wtela/...) via /w. Maior "
        + "volume esperado em produção.")
@RestController
public class DespachoController {

    private static final Logger log = LoggerFactory.getLogger(DespachoController.class);

    private final ObjectMapper mapper;
    private final WcopCrypto crypto;
    private final SessaoUseCase sessoes;
    private final DespachoUseCase despacho;
    private final RotaExecucaoRegistry rotas;   // só p/ LOGAR o trilho escolhido (o roteamento em si é no DespachoUseCase)
    // Tradutor virtual->fisico do ambienteOperacional (VirtualPathToFisical do launcher.pas).
    private final ResolvedorAmbiente resolvedor;
    // Doc Final de Requisitos (2.9.3): fora do modo dev, a requisicao deve ser cifrada (W_COP).
    private final boolean exigirCifrado;

    public DespachoController(ObjectMapper mapper, WcopCrypto crypto,
                              SessaoUseCase sessoes, DespachoUseCase despacho, RotaExecucaoRegistry rotas,
                              ResolvedorAmbiente resolvedor,
                              @Value("${launcher.wcop.exigir-cifrado:false}") boolean exigirCifrado) {
        this.mapper = mapper;
        this.crypto = crypto;
        this.sessoes = sessoes;
        this.despacho = despacho;
        this.rotas = rotas;
        this.resolvedor = resolvedor;
        this.exigirCifrado = exigirCifrado;
    }

    // Aceita os formatos do front (fiel ao AejsWebController legado, que decide pelo REQUEST_METHOD):
    //   1) POST /w                 + corpo JSON  {programName, methodName, requestMethod, ...}   (dispatch)
    //   2) POST /w/{prog}/{met}     + corpo form-encoded  tela=...&sessionKey=...                 (abrir tela)
    //   3) GET  /w/{prog}/{met}?... (params na QUERYSTRING)   combos/stores GET do ExtJS (ledados)
    // Sem o (3), os combos carregados por GET tomavam 404 (Kong/reator so POST) -> combo vazio
    // ("Tipo de taxa invalido" etc.). O legado aceita GET (QUERY_STRING); aqui espelhamos.
    //   4) PUT/DELETE /w/{prog}/{met}  (front React: PutPretendente, OperacaoSalvaSimulacao, ExcluiDocumento)
    //      O legado repassa o REQUEST_METHOD ao programa (Put<metodo>/Delete<metodo>); sem eles davam 405.
    @RequestMapping(value = {"/w", "/w/{prog}/{met}"},
            method = {RequestMethod.GET, RequestMethod.POST, RequestMethod.PUT, RequestMethod.DELETE})
    public ResponseEntity<byte[]> dispatch(HttpServletRequest req,
            @PathVariable(name = "prog", required = false) String progPath,
            @PathVariable(name = "met", required = false) String metPath,
            @RequestBody(required = false) byte[] body) {
        boolean ehGet = "GET".equalsIgnoreCase(req.getMethod());
        // PUT/DELETE sem corpo trazem os params na QUERYSTRING, igual ao GET.
        boolean semCorpoPutDelete = (body == null || body.length == 0)
                && ("PUT".equalsIgnoreCase(req.getMethod()) || "DELETE".equalsIgnoreCase(req.getMethod()));
        boolean usaQuery = ehGet || semCorpoPutDelete;
        String rawAscii = (usaQuery || body == null) ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = !usaQuery && crypto.estaCifrado(rawAscii);
        if (exigirCifrado && !cifrado && !usaQuery && body != null && body.length > 0) {
            log.info("wcop_nao_cifrado_rejeitado");
            return resposta(false,
                    "{\"success\":false,\"message\":\"Requisicao deve ser cifrada (W_COP).\",\"codigo\":\"E006\"}");
        }
        // GET (e PUT/DELETE sem corpo): params na QUERYSTRING (texto puro, sem W_COP).
        // POST/PUT/DELETE com corpo: JSON dispatch OU form ao abrir tela.
        String corpo = usaQuery
                ? mapParaJson(camposDaQuery(req))
                : (cifrado ? crypto.decifraRequest(rawAscii)
                        : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8)));

        // O corpo vem JSON (dispatch) OU form-encoded (abrir tela). Normaliza os campos e o rawJson
        // que vai pro executor (JSON cru preserva nesting; do form monta um JSON flat).
        boolean ehJson = corpo.stripLeading().startsWith("{");
        Map<String, String> in = ehJson ? camposDoJson(corpo) : camposDoForm(corpo);
        String json = ehJson ? corpo : mapParaJson(in);

        // programa/metodo: o PATH (/w/{prog}/{met}) manda; senao o corpo.
        String programName = progPath != null ? progPath : primeiro(in, "programName", "programa");
        String methodName = metPath != null ? metPath : primeiro(in, "methodName", "metodo");
        // requestMethod: o front CIFRADO forca o metodo HTTP para POST mas PRESERVA o metodo ORIGINAL no
        // corpo (app.js: "a.jsonData.requestMethod = a.method; a.method='POST'"). Entao o requestMethod
        // do CORPO e a verdade — ex.: combos/stores GET viram POST cifrado com requestMethod="GET" ->
        // "Get"+metodo. So caimos no verbo HTTP real quando o corpo nao traz (chamada plaintext/dev/curl).
        // Antes o path-based usava req.getMethod() (=POST forcado) -> "Post<metodo>" -> combo vazio
        // ("Tipo de taxa invalido" etc.). Para 'tela', o corpo traz GET/POST reais -> Get/PostTela (ok).
        String requestMethod = primeiro(in, "requestMethod");
        if (requestMethod == null || requestMethod.isBlank() || "null".equalsIgnoreCase(requestMethod)) {
            requestMethod = req.getMethod();
        }

        // VALIDA (papel do launcher): revalida o token ANTES de executar o programa.
        String sessionKey = primeiro(in, "sessionKey");
        // "username" (minusculo) e o que a INTEGRACAO manda (ex.: curl do wintegracaoCDHU com
        // username=loginintegracao); o front ExtJS manda "userName". Aceita as duas grafias + "usuario".
        String usuarioParam = primeiro(in, "userName", "username", "usuario");
        // Consumidor da resposta cifrada: loginintegracao = React (decodifica UTF-8); senao ExtJS (Latin-1).
        boolean integracao = SessaoUseCase.USUARIO_INTEGRACAO.equalsIgnoreCase(usuarioParam);
        // traduz o ambiente virtual (ex.: /cfiae/) p/ o fisico ANTES de validar a sessao (a sessao foi
        // gravada no login ja com o caminho fisico) e de propagar ao scci-core/launcher-sdk/Pascal.
        String ambienteParam = resolvedor.resolver(primeiro(in, "ambienteOperacional", "ambiente"));
        Optional<Sessao> s = sessoes.validar(sessionKey, usuarioParam, ambienteParam);

        // Se veio sessionKey mas a sessao NAO e valida -> rejeita (nao executa). Sem sessionKey
        // (chamada de dev/curl), segue com os parametros (facilita teste local).
        if (sessionKey != null && s.isEmpty()) {
            log.info("w_dispatch_sessao_invalida", kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuarioParam)),
                    kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())),
                    kv("sessaoId", LogAnonimizador.pseudonimizarSessao(sessionKey)));
            return resposta(cifrado, integracao,
                    "{\"success\":false,\"message\":\"Sessao expirada. Faca login novamente.\",\"codigo\":\"E004\"}");
        }
        String usuario = s.map(Sessao::usuario).orElse(usuarioParam);
        String ambiente = s.map(Sessao::ambienteOperacional).orElse(ambienteParam);

        String paramsDbg = in.toString();
        if (paramsDbg.length() > 600) {
            paramsDbg = paramsDbg.substring(0, 600);
        }
        log.info("w_dispatch", kv("programName", programName), kv("methodName", methodName),
                kv("requestMethod", requestMethod), kv("trilho", rotas.trilho(programName)),
                kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())),
                kv("sessaoId", LogAnonimizador.pseudonimizarSessao(sessionKey)),
                kv("sessaoValida", s.isPresent()), kv("params", paramsDbg));

        ResultadoExecucao r = despacho.despachar(new ComandoExecucao(
                ambiente, programName, methodName, requestMethod, json, usuario, req.getRemoteAddr()));
        return resposta(cifrado, integracao, r.corpo());
    }

    private ResponseEntity<byte[]> resposta(boolean cifrado, String json) {
        return resposta(cifrado, false, json);   // default ExtJS (Latin-1); erros ASCII nao dependem disso
    }

    private ResponseEntity<byte[]> resposta(boolean cifrado, boolean integracao, String json) {
        if (cifrado) {
            // paraIso normaliza o acento pra Unicode; o charset da cifra e POR CONSUMIDOR: React
            // (loginintegracao) decodifica UTF-8; ExtJS le Latin-1 (senao "Ã§" no ExtJS ou invalido no React).
            String rotulo = integracao ? "UTF-8" : "ISO-8859-1";
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, "application/json; charset=" + rotulo)
                    .body(crypto.cifraResposta(RespostaCharset.paraIso(json),
                            integracao ? StandardCharsets.UTF_8 : StandardCharsets.ISO_8859_1));
        }
        // Resposta plaintext: repassa se o programa ja saiu em UTF-8 (nao re-encoda -> evita o double-encode
        // "informaÃ§Ã£o"), senao converte ISO-8859-1->UTF-8. Mesma regra pros canais /sccidoc e login.
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, "application/json; charset=UTF-8")
                .body(RespostaCharset.corpoPlaintext(json));
    }

    private Map<String, String> camposDoJson(String json) {
        Map<String, String> m = new LinkedHashMap<>();
        try {
            JsonNode node = mapper.readTree(json);
            if (node != null && node.isObject()) {
                node.fields().forEachRemaining(e -> m.put(e.getKey(), e.getValue().asText()));
            }
        } catch (Exception ignore) {
            // corpo nao-JSON
        }
        return m;
    }

    private static String primeiro(Map<String, String> m, String... chaves) {
        for (String k : chaves) {
            String v = m.get(k);
            if (v != null && !v.isBlank()) {
                return v;
            }
        }
        return null;
    }

    /** Parse do corpo form-encoded (chave=valor&chave=valor) — o formato do front ao abrir tela. */
    private Map<String, String> camposDoForm(String corpo) {
        Map<String, String> m = new LinkedHashMap<>();
        if (corpo == null || corpo.isBlank()) {
            return m;
        }
        for (String par : corpo.split("&")) {
            int eq = par.indexOf('=');
            if (eq <= 0) {
                continue;   // ignora chave vazia (ex.: o "=&" inicial que o front manda)
            }
            m.put(urlDecode(par.substring(0, eq)), urlDecode(par.substring(eq + 1)));
        }
        return m;
    }

    /** Params da QUERYSTRING (chamadas GET do front — stores/combos do ExtJS carregados por GET). */
    private static Map<String, String> camposDaQuery(HttpServletRequest req) {
        Map<String, String> m = new LinkedHashMap<>();
        req.getParameterMap().forEach((k, v) -> {
            if (v != null && v.length > 0 && v[0] != null) {
                m.put(k, v[0]);
            }
        });
        return m;
    }

    /** Monta um JSON flat a partir do mapa (do form) — o executor converte pra PMEMORY XML. */
    private String mapParaJson(Map<String, String> m) {
        try {
            return mapper.writeValueAsString(m);
        } catch (Exception e) {
            return "{}";
        }
    }

    private static String urlDecode(String s) {
        try {
            return java.net.URLDecoder.decode(s, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return s;
        }
    }
}
