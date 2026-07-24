package com.prognum.gateway.documentos;

import com.prognum.gateway.documentos.model.RespostaDocumento;
import com.prognum.gateway.documentos.port.in.BaixarDocumentoUseCase;
import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;
import com.prognum.gateway.execucao.port.out.ExecutorPrograma;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/**
 * Canal de DOCUMENTOS (sccidoc), porte do DoRawRemoteCall do sccidoc.pas — mas do jeito Java.
 * Executa o programa (mesmo oserver do /w) e interpreta a resposta:
 *
 *   resposta = [AnsiString: len(4, little-endian) + XML de metadados] + [bytes do arquivo]
 *
 * Se houver metadados com &lt;Nome&gt;, e um ARQUIVO (extrai Tipo/Nome/DOW e o binario); senao, e
 * texto/JSON de passagem. Erro do programa (bloco EXCEPT) ja vem embrulhado em JSON pelo executor.
 * POJO puro.
 */
public class DocumentoService implements BaixarDocumentoUseCase {

    private final ExecutorPrograma executor;

    public DocumentoService(ExecutorPrograma executor) {
        this.executor = executor;
    }

    @Override
    public RespostaDocumento baixar(ComandoExecucao comando) {
        ResultadoExecucao r = executor.executar(comando);
        if (r.erro()) {
            return new RespostaDocumento(true, false, null, null, false, null, r.corpo());
        }
        // o corpo veio como String ISO-8859-1 (1 byte = 1 char), entao os bytes sao preservados
        byte[] raw = r.corpo().getBytes(StandardCharsets.ISO_8859_1);
        if (raw.length >= 4) {
            int len = le32(raw);
            if (len >= 0 && 4 + len <= raw.length) {
                String xml = new String(raw, 4, len, StandardCharsets.ISO_8859_1);
                String nome = tag(xml, "Nome");
                if (nome != null && !nome.isBlank()) {   // tem nome -> e um arquivo
                    String tipo = tag(xml, "Tipo");
                    boolean download = "true".equalsIgnoreCase(tag(xml, "DOW"));
                    byte[] bin = Arrays.copyOfRange(raw, 4 + len, raw.length);
                    return new RespostaDocumento(false, true, tipo, nome, download, bin, null);
                }
            }
        }
        // nao e arquivo -> texto/JSON de passagem
        return new RespostaDocumento(false, false, null, null, false, null, r.corpo());
    }

    /** Int32 little-endian (formato do TStream.WriteAnsiString do Pascal em x86). */
    private static int le32(byte[] b) {
        return (b[0] & 0xFF) | ((b[1] & 0xFF) << 8) | ((b[2] & 0xFF) << 16) | ((b[3] & 0xFF) << 24);
    }

    /** Extrai o valor de &lt;tag&gt;valor&lt;/tag&gt; (primeira ocorrencia, case-insensitive). */
    private static String tag(String xml, String tag) {
        String low = xml.toLowerCase();
        String open = "<" + tag.toLowerCase();
        int i = low.indexOf(open);
        if (i < 0) {
            return null;
        }
        int gt = low.indexOf('>', i);
        int close = low.indexOf("</" + tag.toLowerCase(), gt);
        if (gt < 0 || close < 0) {
            return null;
        }
        return xml.substring(gt + 1, close).trim();
    }
}
