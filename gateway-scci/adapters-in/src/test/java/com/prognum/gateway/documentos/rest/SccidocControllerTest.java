package com.prognum.gateway.documentos.rest;

import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Evidência dos helpers do canal /sccidoc: strip do [LE32] na resposta de upload e mime por extensão. */
class SccidocControllerTest {

    @Test
    void desembrulha_tira_o_prefixo_de_tamanho_da_resposta_de_upload() {
        // o PostDocumentoOperacao devolve [LE32 len][JSON] (SaveToStreamWithSize) -> precisa tirar o prefixo
        String json = "{\"success\":true}";
        String comPrefixo = comLE32(json);
        assertThat(SccidocController.desembrulhaTamanho(comPrefixo)).isEqualTo(json);
    }

    @Test
    void desembrulha_json_plano_sem_prefixo_fica_igual() {
        // sem prefixo válido, os 4 primeiros bytes ('{','"'...) dariam um tamanho gigante -> devolve como veio
        String json = "{\"success\":false}";
        assertThat(SccidocController.desembrulhaTamanho(json)).isEqualTo(json);
    }

    @Test
    void mime_por_extensao() {
        assertThat(SccidocController.mime(".PDF")).isEqualTo("application/pdf");
        assertThat(SccidocController.mime(".pdf")).isEqualTo("application/pdf");   // case-insensitive
        assertThat(SccidocController.mime(".XLSX"))
                .isEqualTo("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        assertThat(SccidocController.mime(".ZIP")).isEqualTo("application/zip");
        assertThat(SccidocController.mime(".PNG")).isEqualTo("image/png");
        assertThat(SccidocController.mime(".xyz")).isEqualTo("application/octet-stream");
        assertThat(SccidocController.mime(null)).isEqualTo("application/octet-stream");
    }

    // ---- POST com corpo cru (SOAP) -- porte do DecodeParams + DoRawRemoteCall do sccidoc.pas ----

    private static final String SOAP = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
            + "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:cdhu=\"urn:x\">"
            + "<soapenv:Header/><soapenv:Body><cdhu:geraBoleto><entrada><contrato>123</contrato></entrada>"
            + "</cdhu:geraBoleto></soapenv:Body></soapenv:Envelope>";

    @Test
    void pmemory_soap_renomeia_a_raiz_e_preserva_prefixos_e_atributos() {
        String pm = SccidocController.montaPmemoryXml(SOAP, new LinkedHashMap<>());
        // o PostSoapCDHU procura Envelope['soapenv:Body'] -> prefixo e conteudo intactos
        assertThat(pm).startsWith("<?xml version=\"1.0\" encoding=\"UTF-8\"?><PMEMORY xmlns:soapenv=");
        assertThat(pm).contains("<soapenv:Body><cdhu:geraBoleto><entrada><contrato>123</contrato></entrada>");
        assertThat(pm).endsWith("</PMEMORY>");
        assertThat(pm).doesNotContain("soapenv:Envelope");
    }

    @Test
    void pmemory_soap_acrescenta_os_params_de_controle_no_fim_escapados() {
        Map<String, String> filhos = new LinkedHashMap<>();
        filhos.put("USERNAME", "loginintegracao");
        filhos.put("SESSIONKEY", null);                         // nulo nao entra
        filhos.put("AMBIENTEOPERACIONAL", "/cdhu/api");
        filhos.put("obs", "a<b&c");
        filhos.put("nome invalido", "x");                      // nome invalido de tag nao entra
        String pm = SccidocController.montaPmemoryXml(SOAP, filhos);
        assertThat(pm).endsWith("</soapenv:Body><USERNAME>loginintegracao</USERNAME>"
                + "<AMBIENTEOPERACIONAL>/cdhu/api</AMBIENTEOPERACIONAL><obs>a&lt;b&amp;c</obs></PMEMORY>");
        assertThat(pm).doesNotContain("SESSIONKEY").doesNotContain("nome invalido");
    }

    @Test
    void pmemory_aceita_raiz_auto_fechada_e_comentario_antes() {
        String pm = SccidocController.montaPmemoryXml("<!-- c --><raiz a=\"1\"/>", Map.of("X", "1"));
        assertThat(pm).isEqualTo("<!-- c --><PMEMORY a=\"1\"><X>1</X></PMEMORY>");
    }

    @Test
    void pmemory_sem_elemento_raiz_falha() {
        assertThatThrownBy(() -> SccidocController.montaPmemoryXml("<?xml version=\"1.0\"?>", Map.of()))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void resposta_do_PostSoapCDHU_cabecalho_json_com_tipo_vira_text_xml() {
        // PostSoapCDHU: [LE32]{"Tipo":".TEXT/XML","success":true} + XML da resposta SOAP
        String soapResp = "<soapenv:Envelope><soapenv:Body><ok/></soapenv:Body></soapenv:Envelope>";
        String raw = comLE32("{\"Tipo\":\".TEXT/XML\",\"success\":true}") + soapResp;
        SccidocController.CorpoComTipo ct = SccidocController.corpoComTipo(raw);
        assertThat(ct).isNotNull();
        assertThat(ct.tipo()).isEqualTo(".TEXT/XML");
        assertThat(SccidocController.mime(ct.tipo())).isEqualTo("text/xml");
        assertThat(new String(ct.corpo(), StandardCharsets.ISO_8859_1)).isEqualTo(soapResp);
    }

    @Test
    void resposta_com_cabecalho_xml_com_tipo_tambem_e_reconhecida() {
        SccidocController.CorpoComTipo ct = SccidocController.corpoComTipo(comLE32("<Tipo>.txt</Tipo>") + "abc");
        assertThat(ct.tipo()).isEqualTo(".txt");
        assertThat(new String(ct.corpo(), StandardCharsets.ISO_8859_1)).isEqualTo("abc");
    }

    @Test
    void resposta_sem_prefixo_ou_sem_tipo_nao_e_corpo_com_tipo() {
        assertThat(SccidocController.corpoComTipo("{\"success\":true}")).isNull();
        assertThat(SccidocController.corpoComTipo(comLE32("{\"success\":true}") + "x")).isNull();
        assertThat(SccidocController.corpoComTipo(null)).isNull();
    }

    /** [tamanho(4, little-endian)] + bytes (ISO-8859-1). */
    private static String comLE32(String s) {
        byte[] b = s.getBytes(StandardCharsets.ISO_8859_1);
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        bos.write(b.length & 0xFF);
        bos.write((b.length >> 8) & 0xFF);
        bos.write((b.length >> 16) & 0xFF);
        bos.write((b.length >> 24) & 0xFF);
        bos.writeBytes(b);
        return new String(bos.toByteArray(), StandardCharsets.ISO_8859_1);
    }
}
