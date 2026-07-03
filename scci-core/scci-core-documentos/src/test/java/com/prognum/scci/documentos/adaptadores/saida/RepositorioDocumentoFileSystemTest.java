package com.prognum.scci.documentos.adaptadores.saida;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Path;

import org.junit.jupiter.api.Test;

/**
 * Trava o porte do storage FileSystem (RetornaFileSystemName / EncodeInvBase64ForFilenames, wsistarqlib)
 * contra o arquivo REAL confirmado ao vivo no ambiente scat112934:
 * {@code id=290, versao=1 -> /u10/c6bank/suporte/scat112934/doc/I/g/E/IgEAAA.001}.
 */
class RepositorioDocumentoFileSystemTest {

    private RepositorioDocumentoJdbc adapter(String armazenaDir, boolean caseInsensitive) {
        return new RepositorioDocumentoJdbc(null, null, armazenaDir, caseInsensitive);
    }

    @Test
    void encoder_bate_com_o_arquivo_real() {
        // 290 -> 4 bytes LE [0x22,0x01,0x00,0x00] -> base64 "IgEAAA==" -> copy(1,6) "IgEAAA"
        assertThat(RepositorioDocumentoJdbc.encodeInvBase64ForFilenames(290)).isEqualTo("IgEAAA");
    }

    @Test
    void path_case_sensitive_bate_com_o_arquivo_real() {
        Path p = adapter("/u10/c6bank/suporte/scat112934/doc", false).caminhoFileSystem("qualquer", 290, 1);
        assertThat(p).isEqualTo(Path.of("/u10/c6bank/suporte/scat112934/doc/I/g/E/IgEAAA.001"));
    }

    @Test
    void base_default_e_ambiente_barra_doc() {
        // armazena-dir vazio -> <ambiente>/doc (confirmado: scat112934 cai nesse fallback)
        Path p = adapter("", false).caminhoFileSystem("/u10/c6bank/suporte/scat112934", 290, 1);
        assertThat(p).isEqualTo(Path.of("/u10/c6bank/suporte/scat112934/doc/I/g/E/IgEAAA.001"));
    }

    @Test
    void case_insensitive_sufixa_id_e_versao() {
        // ChangeFileExt case-insensitive: enc + '.' + id + '.' + intstr2(versao,3)
        Path p = adapter("/base", true).caminhoFileSystem("amb", 290, 12);
        assertThat(p).isEqualTo(Path.of("/base/I/g/E/IgEAAA.290.012"));
    }
}
