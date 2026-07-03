package com.prognum.scci.documentos.domain;

import java.util.Locale;
import java.util.Map;

/**
 * Mapeia a EXTENSÃO do arquivo para o content-type — versão idiomática Java do {@code case} de tipos do
 * sccidoc.pas (DoRawRemoteCall). Retorna {@code application/octet-stream} quando não conhece a extensão.
 */
public final class TipoMime {

    private static final String PADRAO = "application/octet-stream";

    private static final Map<String, String> POR_EXTENSAO = Map.ofEntries(
            Map.entry("pdf", "application/pdf"),
            Map.entry("xml", "application/xml"),
            Map.entry("jpg", "image/jpeg"),
            Map.entry("jpeg", "image/jpeg"),
            Map.entry("bmp", "image/bmp"),
            Map.entry("png", "image/png"),
            Map.entry("tif", "image/tiff"),
            Map.entry("tiff", "image/tiff"),
            Map.entry("gif", "image/gif"),
            Map.entry("htm", "text/html"),
            Map.entry("html", "text/html"),
            Map.entry("rtf", "text/rtf"),
            Map.entry("txt", "text/plain"),
            Map.entry("csv", "text/csv"),
            Map.entry("ogg", "audio/ogg"),
            Map.entry("mp4", "video/mp4"),
            Map.entry("zip", "application/zip"),
            Map.entry("bin", "application/octet-stream"),
            Map.entry("doc", "application/msword"),
            Map.entry("dot", "application/msword"),
            Map.entry("xls", "application/vnd.ms-excel"),
            Map.entry("xlt", "application/vnd.ms-excel"),
            Map.entry("xla", "application/vnd.ms-excel"),
            Map.entry("ppt", "application/vnd.ms-powerpoint"),
            Map.entry("pot", "application/vnd.ms-powerpoint"),
            Map.entry("pps", "application/vnd.ms-powerpoint"),
            Map.entry("docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
            Map.entry("dotx", "application/vnd.openxmlformats-officedocument.wordprocessingml.template"),
            Map.entry("xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
            Map.entry("xltx", "application/vnd.openxmlformats-officedocument.spreadsheetml.template"),
            Map.entry("pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation"),
            Map.entry("ppsx", "application/vnd.openxmlformats-officedocument.presentationml.slideshow"),
            Map.entry("potx", "application/vnd.openxmlformats-officedocument.presentationml.template"),
            Map.entry("odt", "application/vnd.oasis.opendocument.text"),
            Map.entry("ods", "application/vnd.oasis.opendocument.spreadsheet"),
            Map.entry("odp", "application/vnd.oasis.opendocument.presentation"));

    private TipoMime() {
    }

    /** Content-type a partir do NOME do arquivo (usa a extensão). */
    public static String doNome(String nome) {
        return porExtensao(extensao(nome));
    }

    /** Content-type a partir da extensão (com ou sem o ponto). */
    public static String porExtensao(String ext) {
        if (ext == null) {
            return PADRAO;
        }
        String e = ext.startsWith(".") ? ext.substring(1) : ext;
        return POR_EXTENSAO.getOrDefault(e.toLowerCase(Locale.ROOT), PADRAO);
    }

    /** Extensão (sem o ponto, minúscula) de um nome de arquivo; vazio se não tiver. */
    public static String extensao(String nome) {
        if (nome == null) {
            return "";
        }
        int p = nome.lastIndexOf('.');
        return p < 0 ? "" : nome.substring(p + 1).toLowerCase(Locale.ROOT);
    }
}
