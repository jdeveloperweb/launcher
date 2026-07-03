package com.prognum.scci.documentos.adaptadores.saida;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Trava o porte do storage FileSystem ({@link LocalizadorArmazenamento} — RetornaFileSystemName /
 * EncodeInvBase64ForFilenames, wsistarqlib) contra o arquivo REAL confirmado ao vivo no ambiente
 * scat112934: {@code id=290, versao=1 -> /u10/c6bank/suporte/scat112934/doc/I/g/E/IgEAAA.001}.
 */
class RepositorioDocumentoFileSystemTest {

    private LocalizadorArmazenamento loc(String armazenaDir, boolean caseInsensitive) {
        return new LocalizadorArmazenamento(armazenaDir, caseInsensitive);
    }

    @Test
    void encoder_bate_com_o_arquivo_real() {
        // 290 -> 4 bytes LE [0x22,0x01,0x00,0x00] -> base64 "IgEAAA==" -> copy(1,6) "IgEAAA"
        assertThat(LocalizadorArmazenamento.encodeInvBase64ForFilenames(290)).isEqualTo("IgEAAA");
    }

    @Test
    void path_case_sensitive_bate_com_o_arquivo_real() {
        Path p = loc("/u10/c6bank/suporte/scat112934/doc", false).caminho("qualquer", 290, 1);
        assertThat(p).isEqualTo(Path.of("/u10/c6bank/suporte/scat112934/doc/I/g/E/IgEAAA.001"));
    }

    @Test
    void base_default_e_ambiente_barra_doc() {
        // armazena-dir vazio -> <ambiente>/doc (confirmado: scat112934 cai nesse fallback)
        Path p = loc("", false).caminho("/u10/c6bank/suporte/scat112934", 290, 1);
        assertThat(p).isEqualTo(Path.of("/u10/c6bank/suporte/scat112934/doc/I/g/E/IgEAAA.001"));
    }

    @Test
    void case_insensitive_sufixa_id_e_versao() {
        // ChangeFileExt case-insensitive: enc + '.' + id + '.' + intstr2(versao,3)
        Path p = loc("/base", true).caminho("amb", 290, 12);
        assertThat(p).isEqualTo(Path.of("/base/I/g/E/IgEAAA.290.012"));
    }

    @Test
    void usa_filesystem_quando_o_dir_base_existe(@TempDir Path amb) throws Exception {
        // ambiente com <ambiente>/doc existente -> FileSystem (fiel a RetornaLocalArmazenaDocImgs + DirectoryExists)
        Files.createDirectories(amb.resolve("doc"));
        assertThat(loc("", false).usaFileSystem(amb.toString())).isTrue();
    }

    @Test
    void grava_no_banco_quando_nao_ha_dir_de_imagens(@TempDir Path amb) {
        // sem <ambiente>/doc -> DB-blob (o Pascal limpa LocalArmazenaDocImgs quando o dir nao existe)
        assertThat(loc("", false).usaFileSystem(amb.resolve("inexistente").toString())).isFalse();
    }
}
