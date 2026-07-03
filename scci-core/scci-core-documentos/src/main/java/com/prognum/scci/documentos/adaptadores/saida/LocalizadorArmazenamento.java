package com.prognum.scci.documentos.adaptadores.saida;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Resolve ONDE o binário do documento vive — porte de {@code RetornaLocalArmazenaDocImgs} /
 * {@code RetornaFileSystemName} / {@code EncodeInvBase64ForFilenames} (wsistarqlib). Centraliza a decisão
 * <b>FileSystem × banco</b> e a construção do caminho em disco, para o read ({@link RepositorioDocumentoJdbc})
 * e o write ({@link ArmazenadorDocumentoJdbc}) usarem a MESMA regra.
 *
 * <p>Decisão fiel ao Pascal: usa FileSystem quando {@code RetornaLocalArmazenaDocImgs > ''} <b>e</b> o
 * diretório existe ({@code DirectoryExists}); senão grava o BLOB no banco. O diretório-base
 * ({@code scciconf.LocalArmazenaDocImgs}) é configurável por {@code scci.documentos.armazena-dir}; se vazio,
 * usa o default {@code <ambiente>/doc} (confirmado ao vivo no scat112934).</p>
 *
 * <p>Caminho: {@code <base>/<e0>/<e1>/<e2>/<enc>[.<id>].<versao3>}, {@code enc} = 6 primeiros chars do base64
 * dos 4 bytes little-endian do ID, com {@code '/'→'_'}.</p>
 */
@Component
public class LocalizadorArmazenamento {

    private final String armazenaDir;
    private final boolean caseInsensitive;

    public LocalizadorArmazenamento(
            @Value("${scci.documentos.armazena-dir:}") String armazenaDir,
            @Value("${scci.documentos.case-insensitive:false}") boolean caseInsensitive) {
        this.armazenaDir = armazenaDir == null ? "" : armazenaDir.trim();
        this.caseInsensitive = caseInsensitive;
    }

    /** Diretório-base do storage de imagens do ambiente (scciconf.LocalArmazenaDocImgs ou {@code <ambiente>/doc}). */
    public String baseDir(String ambiente) {
        if (!armazenaDir.isEmpty()) {
            return armazenaDir;
        }
        return (ambiente == null ? "" : ambiente).replaceAll("[\\\\/]+$", "") + "/doc";
    }

    /**
     * O ambiente usa FileSystem? (RetornaLocalArmazenaDocImgs {@code > ''} e {@code DirectoryExists}). Se não,
     * o documento vai como BLOB no banco. É a chave da fidelidade do WRITE: num ambiente FS, grava em disco.
     */
    public boolean usaFileSystem(String ambiente) {
        String base = baseDir(ambiente);
        return !base.isBlank() && Files.isDirectory(Path.of(base));
    }

    /** {@code <base>/<e0>/<e1>/<e2>/<enc>[.<id>].<versao3>} — porte de {@code RetornaFileSystemName}. */
    public Path caminho(String ambiente, int id, int versao) {
        String base = baseDir(ambiente);
        String enc = encodeInvBase64ForFilenames(id);
        String versao3 = String.format("%03d", versao);           // intstr2(Versao,3)
        String arquivo = caseInsensitive ? enc + "." + id + "." + versao3 : enc + "." + versao3;
        return Path.of(base, enc.substring(0, 1), enc.substring(1, 2), enc.substring(2, 3), arquivo);
    }

    /**
     * Porte de {@code EncodeInvBase64ForFilenames}: 6 primeiros chars do base64 dos 4 bytes little-endian do
     * ID, com {@code '/'→'_'}. Ex.: {@code 290 -> "IgEAAA"}.
     */
    public static String encodeInvBase64ForFilenames(int id) {
        byte[] le = { (byte) id, (byte) (id >> 8), (byte) (id >> 16), (byte) (id >> 24) };
        String b64 = Base64.getEncoder().encodeToString(le);      // 8 chars ("...=="); copy(1,6) -> 6 primeiros
        return b64.substring(0, 6).replace('/', '_');
    }
}
