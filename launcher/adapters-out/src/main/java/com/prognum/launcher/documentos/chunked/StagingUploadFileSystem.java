package com.prognum.launcher.documentos.chunked;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.prognum.launcher.documentos.model.UploadChunkado;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.UploadNaoEncontrado;
import com.prognum.launcher.documentos.port.out.RepositorioUploadChunked;

/**
 * Doc Final de Requisitos (Upload/Download): staging em disco do upload chunked — um diretório por
 * upload ({@code <staging-dir>/<uploadId>/}), um arquivo {@code bloco-N.part} por bloco recebido e um
 * {@code meta.json} com os metadados ({@link UploadChunkado}). Idempotente por bloco (reenviar o
 * mesmo número sobrescreve) — dá suporte a retomada após falha de rede.
 */
@Component
public class StagingUploadFileSystem implements RepositorioUploadChunked {

    private static final String ARQUIVO_META = "meta.json";
    private static final String PREFIXO_BLOCO = "bloco-";
    private static final String SUFIXO_BLOCO = ".part";

    private final Path baseDir;
    private final ObjectMapper mapper;

    public StagingUploadFileSystem(ObjectMapper mapper,
            @Value("${launcher.documentos.chunked.staging-dir:${java.io.tmpdir}/scci-upload-staging}") String stagingDir) {
        this.mapper = mapper;
        this.baseDir = Path.of(stagingDir);
    }

    @Override
    public void iniciar(UploadChunkado sessao) {
        try {
            Path dir = dirDe(sessao.id());
            Files.createDirectories(dir);
            Files.writeString(dir.resolve(ARQUIVO_META), mapper.writeValueAsString(sessao));
        } catch (IOException e) {
            throw new IllegalStateException("falha ao iniciar staging do upload " + sessao.id(), e);
        }
    }

    @Override
    public Optional<UploadChunkado> metadados(String uploadId) {
        Path metaFile = dirDe(uploadId).resolve(ARQUIVO_META);
        if (!Files.isRegularFile(metaFile)) {
            return Optional.empty();
        }
        try {
            return Optional.of(mapper.readValue(Files.readString(metaFile), UploadChunkado.class));
        } catch (IOException e) {
            return Optional.empty();
        }
    }

    @Override
    public void gravarBloco(String uploadId, int numero, byte[] dados) {
        Path dir = dirDe(uploadId);
        if (!Files.isDirectory(dir)) {
            throw new UploadNaoEncontrado(uploadId);
        }
        try {
            Files.write(dir.resolve(PREFIXO_BLOCO + numero + SUFIXO_BLOCO), dados);
        } catch (IOException e) {
            throw new IllegalStateException("falha ao gravar bloco " + numero + " do upload " + uploadId, e);
        }
    }

    @Override
    public Set<Integer> blocosRecebidos(String uploadId) {
        Path dir = dirDe(uploadId);
        if (!Files.isDirectory(dir)) {
            return Set.of();
        }
        try (Stream<Path> arquivos = Files.list(dir)) {
            return arquivos.map(p -> p.getFileName().toString())
                    .filter(n -> n.startsWith(PREFIXO_BLOCO) && n.endsWith(SUFIXO_BLOCO))
                    .map(n -> Integer.parseInt(n.substring(PREFIXO_BLOCO.length(), n.length() - SUFIXO_BLOCO.length())))
                    .collect(Collectors.toSet());
        } catch (IOException e) {
            throw new IllegalStateException("falha ao listar blocos do upload " + uploadId, e);
        }
    }

    @Override
    public long bytesRecebidos(String uploadId) {
        Path dir = dirDe(uploadId);
        if (!Files.isDirectory(dir)) {
            return 0;
        }
        try (Stream<Path> arquivos = Files.list(dir)) {
            return arquivos.filter(p -> p.getFileName().toString().startsWith(PREFIXO_BLOCO))
                    .mapToLong(this::tamanho)
                    .sum();
        } catch (IOException e) {
            throw new IllegalStateException("falha ao somar bytes do upload " + uploadId, e);
        }
    }

    @Override
    public Path montar(String uploadId) {
        UploadChunkado meta = metadados(uploadId).orElseThrow(() -> new UploadNaoEncontrado(uploadId));
        Path dir = dirDe(uploadId);
        Path destino = dir.resolve("montado.bin");
        try (OutputStream out = Files.newOutputStream(destino)) {
            for (int i = 0; i < meta.totalBlocos(); i++) {
                Path bloco = dir.resolve(PREFIXO_BLOCO + i + SUFIXO_BLOCO);
                if (!Files.isRegularFile(bloco)) {
                    throw new IllegalStateException("bloco " + i + " ausente no upload " + uploadId);
                }
                Files.copy(bloco, out);   // streaming — nunca materializa o arquivo inteiro em memoria aqui
            }
        } catch (IOException e) {
            throw new IllegalStateException("falha ao montar o upload " + uploadId, e);
        }
        return destino;
    }

    @Override
    public void remover(String uploadId) {
        Path dir = dirDe(uploadId);
        if (!Files.isDirectory(dir)) {
            return;
        }
        apagarRecursivo(dir);
    }

    @Override
    public List<String> idsExistentes() {
        if (!Files.isDirectory(baseDir)) {
            return List.of();
        }
        try (Stream<Path> dirs = Files.list(baseDir)) {
            return dirs.filter(Files::isDirectory).map(p -> p.getFileName().toString()).toList();
        } catch (IOException e) {
            throw new IllegalStateException("falha ao listar uploads em staging", e);
        }
    }

    private Path dirDe(String uploadId) {
        // uploadId e gerado internamente como hex (16 bytes aleatorios) -- sem separador de path;
        // ainda assim resolve() do NIO nao segue ".." implicitamente aqui pois validamos o formato.
        if (uploadId == null || !uploadId.matches("[0-9a-f]{32}")) {
            throw new UploadNaoEncontrado(String.valueOf(uploadId));
        }
        return baseDir.resolve(uploadId);
    }

    private long tamanho(Path p) {
        try {
            return Files.size(p);
        } catch (IOException e) {
            return 0L;
        }
    }

    private static void apagarRecursivo(Path dir) {
        try (Stream<Path> arquivos = Files.walk(dir)) {
            arquivos.sorted(Comparator.reverseOrder()).forEach(p -> {
                try {
                    Files.deleteIfExists(p);
                } catch (IOException ignore) {
                    // best-effort: o job de limpeza tenta novamente na próxima varredura
                }
            });
        } catch (IOException ignore) {
            // diretorio pode ja ter sido removido concorrentemente
        }
    }
}
