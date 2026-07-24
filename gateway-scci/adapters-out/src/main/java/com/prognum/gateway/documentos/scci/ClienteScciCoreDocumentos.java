package com.prognum.gateway.documentos.scci;

import java.util.Optional;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.prognum.gateway.documentos.model.RespostaDocumento;
import com.prognum.gateway.documentos.port.out.DocumentosJavaPort;
import com.prognum.gateway.execucao.model.ComandoExecucao;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

/**
 * Cliente do REST interno do <b>scci-core/documentos</b> — o caminho JAVA do roteador. Mapeia o método do
 * {@code wdoc} para o endpoint interno, extrai os params do {@code rawJson}, chama o scci-core e converte a
 * resposta (bytes + Content-Type + Content-Disposition) num {@link RespostaDocumento} do launcher.
 *
 * Devolve {@link Optional#empty()} quando: (a) o método não é um read migrado (→ fallback Pascal); ou
 * (b) o scci-core está inacessível (→ fallback Pascal, resiliência). Um 404 do scci-core vira erro de
 * documento (não faz fallback — o Pascal também não acharia).
 */
@Component
public class ClienteScciCoreDocumentos implements DocumentosJavaPort {

    private static final Logger log = LoggerFactory.getLogger(ClienteScciCoreDocumentos.class);

    private final RestClient rest;
    private final ObjectMapper mapper;

    public ClienteScciCoreDocumentos(RestClient.Builder builder, ObjectMapper mapper,
                                     @Value("${launcher.scci-core.url:http://localhost:8090}") String baseUrl) {
        this.mapper = mapper;
        // builder GERENCIADO (instrumentado) — propaga o traceparent p/ ligar o trace launcher -> scci-core
        this.rest = builder.baseUrl(baseUrl).build();
    }

    @Override
    public Optional<RespostaDocumento> baixar(ComandoExecucao c) {
        String metodo = canonico(c.methodName());
        JsonNode p = parse(c.rawJson());
        String amb = c.ambiente();
        try {
            return switch (metodo) {
                case "DOCUMENTO" -> porId(inteiro(p, "ID"), amb, false);
                case "DOCUMENTOCONTRATOASSINATURA" -> porId(inteiro(p, "ID"), amb, true);
                case "DOCUMENTOVERSAO" -> Optional.of(get(amb, u -> u
                        .path("/interno/documentos/{id}/versoes/{v}")
                        .queryParam("ambiente", amb).queryParam("download", false)
                        .build(inteiro(p, "ID"), inteiro(p, "VERSAO"))));
                case "DOCUMENTOOPERACAO" -> operacao(p, amb, false);
                case "DOCUMENTOOPERACAOASSINATURA" -> operacao(p, amb, true);
                case "DOCUMENTOSISAT" -> Optional.of(get(amb, u -> u
                        .path("/interno/documentos/sisat")
                        .queryParam("nuOcorrencia", inteiro(p, "NU_OCORRENCIA"))
                        .queryParam("nuDocumento", texto(p, "NU_DOCUMENTO"))
                        .queryParam("ambiente", amb).build()));
                default -> Optional.empty();       // método não migrado -> Pascal
            };
        } catch (DocumentoNaoEncontradoRemoto e) {
            return Optional.of(new RespostaDocumento(true, false, null, null, false, null,
                    "{\"success\":false,\"message\":\"Documento nao encontrado.\"}"));
        } catch (RuntimeException e) {
            log.warn("scci_core_documentos_indisponivel metodo={} erro={} -> fallback Pascal",
                    metodo, String.valueOf(e.getMessage()));
            return Optional.empty();               // scci-core fora -> fallback Pascal
        }
    }

    private Optional<RespostaDocumento> porId(int id, String amb, boolean download) {
        return Optional.of(get(amb, u -> u.path("/interno/documentos/{id}")
                .queryParam("ambiente", amb).queryParam("download", download).build(id)));
    }

    private Optional<RespostaDocumento> operacao(JsonNode p, String amb, boolean download) {
        boolean cs = "true".equalsIgnoreCase(texto(p, "BuscaComCaseSensitive"));
        return Optional.of(get(amb, u -> u.path("/interno/documentos/operacao")
                .queryParam("nuPretendente", texto(p, "NU_PRETENDENTE"))
                .queryParam("nuDocumento", texto(p, "NU_DOCUMENTO"))
                .queryParam("caseSensitive", cs).queryParam("download", download)
                .queryParam("ambiente", amb).build()));
    }

    private RespostaDocumento get(String amb, java.util.function.Function<org.springframework.web.util.UriBuilder, java.net.URI> uri) {
        try {
            ResponseEntity<byte[]> resp = rest.get().uri(uri).retrieve().toEntity(byte[].class);
            String nome = "documento";
            boolean download = false;
            String cd = resp.getHeaders().getFirst(HttpHeaders.CONTENT_DISPOSITION);
            if (cd != null) {
                ContentDisposition disp = ContentDisposition.parse(cd);
                if (disp.getFilename() != null) {
                    nome = disp.getFilename();
                }
                download = disp.isAttachment();
            }
            byte[] corpo = resp.getBody() == null ? new byte[0] : resp.getBody();
            return new RespostaDocumento(false, true, extensao(nome), nome, download, corpo, null);
        } catch (RestClientResponseException e) {
            if (e.getStatusCode().value() == 404) {
                throw new DocumentoNaoEncontradoRemoto();
            }
            throw e;
        }
    }

    // ---- helpers ----

    @Override
    public Optional<String> enviar(ComandoExecucao c) {
        if (!"DOCUMENTO".equals(canonico(c.methodName()))) {
            return Optional.empty();               // só PostDocumento (genérico) migrado; resto -> Pascal
        }
        JsonNode p = parse(c.rawJson());
        byte[] conteudo = c.corpoBinario() == null ? new byte[0] : c.corpoBinario();
        try {
            String resp = rest.post()
                    .uri(u -> u.path("/interno/documentos")
                            .queryParam("idPai", inteiro(p, "IDPAI"))
                            .queryParam("nome", texto(p, "FileName"))
                            .queryParam("ambiente", c.ambiente())
                            .queryParam("usuario", c.usuario() == null ? "" : c.usuario())
                            .build())
                    .contentType(MediaType.APPLICATION_OCTET_STREAM)
                    .body(conteudo)
                    .retrieve().body(String.class);
            return Optional.of(resp == null ? "{\"success\":true}" : resp);
        } catch (RestClientResponseException e) {
            return Optional.of(e.getResponseBodyAsString());   // erro do scci-core = resposta (não faz fallback)
        } catch (RuntimeException e) {
            log.warn("scci_core_documentos_indisponivel upload erro={} -> fallback Pascal", String.valueOf(e.getMessage()));
            return Optional.empty();               // scci-core fora -> fallback Pascal
        }
    }

    /** Método canônico: MAIÚSCULO sem o prefixo de verbo (Get/Post/Put/Delete) — "PostDocumento"->"DOCUMENTO". */
    private static String canonico(String metodo) {
        String m = metodo == null ? "" : metodo.trim().toUpperCase();
        for (String v : new String[]{"GET", "POST", "PUT", "DELETE"}) {
            if (m.startsWith(v)) {
                return m.substring(v.length());
            }
        }
        return m;
    }

    private static String extensao(String nome) {
        int p = nome.lastIndexOf('.');
        return p < 0 ? "" : nome.substring(p);   // com o ponto (ex.: ".pdf") — o mime() do launcher trata
    }

    private JsonNode parse(String json) {
        try {
            JsonNode n = mapper.readTree(json == null ? "{}" : json);
            return n == null ? mapper.createObjectNode() : n;
        } catch (Exception e) {
            return mapper.createObjectNode();
        }
    }

    /** Valor de uma chave (case-insensitive), como texto; vazio se ausente. */
    private static String texto(JsonNode p, String chave) {
        var it = p.fields();
        while (it.hasNext()) {
            var e = it.next();
            if (e.getKey().equalsIgnoreCase(chave)) {
                return e.getValue().asText("");
            }
        }
        return "";
    }

    private static int inteiro(JsonNode p, String chave) {
        String v = texto(p, chave).trim();
        try {
            return v.isEmpty() ? 0 : Integer.parseInt(v);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private static final class DocumentoNaoEncontradoRemoto extends RuntimeException {
    }
}
