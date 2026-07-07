package com.prognum.scci.documentos.application;

import java.util.Locale;
import java.util.Set;

import com.prognum.scci.documentos.domain.TipoMime;
import com.prognum.scci.documentos.domain.port.in.EnviarDocumento;
import com.prognum.scci.documentos.domain.port.out.AntiMalware;
import com.prognum.scci.documentos.domain.port.out.ArmazenadorDocumento;
import com.prognum.scci.documentos.domain.port.out.ConversorImagemPdf;

/**
 * Upload de documento (porte do fluxo Post* do wdoc): valida extensão → anti-malware → conversão
 * imagem→PDF (se aplicável) → gravação da nova versão no SISTARQ. Orquestra os ports; POJO puro,
 * testável com fakes.
 *
 * <p><b>Doc Final de Requisitos (Upload/Download):</b> lista paramétrica de extensões permitidas —
 * {@code extensoesPermitidas} vazio = nenhuma restrição (mantém compat); não-vazio = allow-list
 * estrita (extensão fora da lista, incluindo arquivo sem extensão, é rejeitada ANTES do
 * anti-malware/conversão).</p>
 */
public class EnviarDocumentoService implements EnviarDocumento {

    private final AntiMalware antiMalware;
    private final ConversorImagemPdf conversor;
    private final ArmazenadorDocumento armazenador;
    private final Set<String> extensoesPermitidas;

    public EnviarDocumentoService(AntiMalware antiMalware, ConversorImagemPdf conversor,
                                  ArmazenadorDocumento armazenador, Set<String> extensoesPermitidas) {
        this.antiMalware = antiMalware;
        this.conversor = conversor;
        this.armazenador = armazenador;
        this.extensoesPermitidas = extensoesPermitidas == null ? Set.of() : extensoesPermitidas;
    }

    @Override
    public int enviar(int id, String nome, byte[] conteudo, String usuario, String ambiente) {
        ConversorImagemPdf.Resultado r = verificarEConverter(conteudo, nome);
        return armazenador.gravarVersao(id, r.nome(), r.conteudo(), usuario, ambiente);
    }

    @Override
    public int enviarParaPasta(int idPai, String nome, byte[] conteudo, String usuario, String ambiente) {
        ConversorImagemPdf.Resultado r = verificarEConverter(conteudo, nome);
        return armazenador.inserirArquivoVersao(idPai, r.nome(), r.conteudo(), usuario, ambiente);
    }

    private ConversorImagemPdf.Resultado verificarEConverter(byte[] conteudo, String nome) {
        validarExtensao(nome);
        antiMalware.verificar(conteudo, nome);                              // reprova => exceção
        return conversor.converter(conteudo, nome);
    }

    private void validarExtensao(String nome) {
        if (extensoesPermitidas.isEmpty()) {
            return;                                    // allow-list desligada (nenhuma extensão configurada)
        }
        String ext = TipoMime.extensao(nome);
        if (!extensoesPermitidas.contains(ext.toLowerCase(Locale.ROOT))) {
            throw new ExtensaoNaoPermitida(ext);
        }
    }

    /** Extensão do arquivo enviado não está na allow-list configurada (scci.documentos.extensoes-permitidas). */
    public static class ExtensaoNaoPermitida extends RuntimeException {
        public ExtensaoNaoPermitida(String extensao) {
            super("Extensao de arquivo nao permitida: " + (extensao == null || extensao.isBlank() ? "(sem extensao)" : "." + extensao));
        }
    }
}
