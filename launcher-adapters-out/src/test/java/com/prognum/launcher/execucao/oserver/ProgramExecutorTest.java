package com.prognum.launcher.execucao.oserver;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.prognum.launcher.execucao.model.ResultadoExecucao;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Evidência da camada de TRANSPORTE (papel do wcorp/oserver): montagem do nome do método,
 * params XML PMEMORY, protocolo de blocos e o prefixo [LE32] do canal de documentos.
 */
class ProgramExecutorTest {

    private static final int DATA = 0xFB, EXCEPT = 0xFD, METD = 0xFA;
    private final ObjectMapper mapper = new ObjectMapper();

    // ---------- montaMetodo (fiel ao sccidoc.pas: prefixa o verbo só se for verbo HTTP) ----------

    @Test
    void montaMetodo_verbo_explicito() {
        assertThat(ProgramExecutor.montaMetodo("GET", "menu")).isEqualTo("GetMenu");
        assertThat(ProgramExecutor.montaMetodo("POST", "tela")).isEqualTo("PostTela");
        assertThat(ProgramExecutor.montaMetodo("get", "menu")).isEqualTo("GetMenu");   // normaliza case
        assertThat(ProgramExecutor.montaMetodo("PUT", "docOCR")).isEqualTo("PutDocOCR");
    }

    @Test
    void montaMetodo_sem_requestMethod_nao_prefixa() {
        // o bug antigo virava "GETDocumentoOperacao"; o correto (Pascal) é sem prefixo
        assertThat(ProgramExecutor.montaMetodo(null, "documentoOperacao")).isEqualTo("DocumentoOperacao");
        assertThat(ProgramExecutor.montaMetodo("", "documentoOperacao")).isEqualTo("DocumentoOperacao");
    }

    @Test
    void montaMetodo_verbo_embutido_no_nome() {
        // "getTipoDocumento" sem requestMethod -> só capitaliza a 1ª letra (verbo já embutido)
        assertThat(ProgramExecutor.montaMetodo(null, "getTipoDocumento")).isEqualTo("GetTipoDocumento");
        assertThat(ProgramExecutor.montaMetodo(null, "putDocumentoOperacaoOCR")).isEqualTo("PutDocumentoOperacaoOCR");
    }

    @Test
    void montaMetodo_verbo_desconhecido_nao_prefixa() {
        assertThat(ProgramExecutor.montaMetodo("XYZ", "menu")).isEqualTo("Menu");
    }

    // ---------- jsonParaPmemoryXml (params como XML raiz <PMEMORY>) ----------

    @Test
    void pmemory_campos_simples() {
        ObjectNode o = mapper.createObjectNode();
        o.put("ID", "10");
        o.put("Fase", "1");
        assertThat(ProgramExecutor.jsonParaPmemoryXml(o))
                .isEqualTo("<PMEMORY><ID>10</ID><Fase>1</Fase></PMEMORY>");
    }

    @Test
    void pmemory_objeto_vazio_vira_elemento_vazio() {
        ObjectNode o = mapper.createObjectNode();
        o.putObject("dados");   // "dados":{} -> <dados></dados> (XML válido, não estoura EXMLParser)
        assertThat(ProgramExecutor.jsonParaPmemoryXml(o))
                .isEqualTo("<PMEMORY><dados></dados></PMEMORY>");
    }

    @Test
    void pmemory_escapa_xml_e_ignora_chave_vazia() {
        ObjectNode o = mapper.createObjectNode();
        o.put("x", "a<b>&c");
        o.put("", "ignorado");   // chave vazia é ignorada (o "":null que o front manda)
        assertThat(ProgramExecutor.jsonParaPmemoryXml(o))
                .isEqualTo("<PMEMORY><x>a&lt;b&gt;&amp;c</x></PMEMORY>");
    }

    // ---------- parseBlocos (protocolo do oserver: relay do 1º bloco, DATA vence EXCEPT) ----------

    @Test
    void parse_bloco_DATA_e_a_resposta() {
        byte[] out = ProgramExecutor.bloco(DATA, "{\"ok\":true}".getBytes(StandardCharsets.ISO_8859_1));
        ResultadoExecucao r = ProgramExecutor.parseBlocos(out);
        assertThat(r.erro()).isFalse();
        assertThat(r.corpo()).isEqualTo("{\"ok\":true}");
    }

    @Test
    void parse_bloco_EXCEPT_vira_json_de_erro() {
        byte[] out = ProgramExecutor.bloco(EXCEPT, "Stream read error".getBytes(StandardCharsets.ISO_8859_1));
        ResultadoExecucao r = ProgramExecutor.parseBlocos(out);
        assertThat(r.erro()).isTrue();
        assertThat(r.corpo()).isEqualTo("{\"success\":false,\"message\":\"Stream read error\"}");
    }

    @Test
    void parse_ignora_METD_e_pega_o_DATA() {
        byte[] out = concat(
                ProgramExecutor.bloco(METD, "GetMenu,".getBytes(StandardCharsets.ISO_8859_1)),
                ProgramExecutor.bloco(DATA, "{\"m\":1}".getBytes(StandardCharsets.ISO_8859_1)));
        assertThat(ProgramExecutor.parseBlocos(out).corpo()).isEqualTo("{\"m\":1}");
    }

    @Test
    void parse_DATA_vence_EXCEPT_posterior() {
        // o programa escreve o DATA e DEPOIS estoura EXCEPT -> relay só do DATA (bug "tela não atualiza")
        byte[] out = concat(
                ProgramExecutor.bloco(DATA, "{\"success\":true}".getBytes(StandardCharsets.ISO_8859_1)),
                ProgramExecutor.bloco(EXCEPT, "erro tardio".getBytes(StandardCharsets.ISO_8859_1)));
        ResultadoExecucao r = ProgramExecutor.parseBlocos(out);
        assertThat(r.erro()).isFalse();
        assertThat(r.corpo()).isEqualTo("{\"success\":true}");
    }

    @Test
    void parse_vazio_e_erro() {
        assertThat(ProgramExecutor.parseBlocos(new byte[0]).erro()).isTrue();
    }

    // ---------- comTamanhoLE (prefixo [tamanho 4, little-endian] do canal de documentos) ----------

    @Test
    void comTamanhoLE_prefixa_o_tamanho() {
        byte[] r = ProgramExecutor.comTamanhoLE(new byte[]{'A', 'B', 'C'});
        assertThat(r).containsExactly(3, 0, 0, 0, 'A', 'B', 'C');
    }

    private static byte[] concat(byte[] a, byte[] b) {
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        bos.writeBytes(a);
        bos.writeBytes(b);
        return bos.toByteArray();
    }
}
