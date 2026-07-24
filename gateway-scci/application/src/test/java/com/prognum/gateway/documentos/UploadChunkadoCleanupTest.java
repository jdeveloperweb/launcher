package com.prognum.gateway.documentos;

import com.prognum.gateway.documentos.model.UploadChunkado;
import com.prognum.gateway.documentos.port.in.EnviarDocumentoUseCase;
import com.prognum.gateway.documentos.port.in.UploadChunkadoUseCase.IniciarUploadComando;
import com.prognum.gateway.documentos.port.in.UploadChunkadoUseCase.ResultadoIniciarUpload;
import com.prognum.gateway.documentos.port.out.RepositorioUploadChunked;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeMap;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Teste de integracao da LIMPEZA de temporarios do upload chunkado — Req. 2.9.7
 * ("armazenamento temporario seguro + tolerancia a falhas, INCLUSIVE em falhas/paradas").
 * Prova que o staging e removido tanto no abortar() quanto no concluir() QUANDO O PIPELINE FALHA
 * (bloco {@code finally} do concluir), nao deixando temporario orfao.
 */
class UploadChunkadoCleanupTest {

    /** Staging fake em memoria; conta as remocoes e materializa em arquivo temp no montar(). */
    static class FakeStaging implements RepositorioUploadChunked {
        final Map<String, UploadChunkado> metas = new HashMap<>();
        final Map<String, TreeMap<Integer, byte[]>> blocos = new HashMap<>();
        int remocoes = 0;

        public void iniciar(UploadChunkado s) { metas.put(s.id(), s); blocos.put(s.id(), new TreeMap<>()); }
        public Optional<UploadChunkado> metadados(String id) { return Optional.ofNullable(metas.get(id)); }
        public void gravarBloco(String id, int n, byte[] d) { blocos.get(id).put(n, d); }
        public Set<Integer> blocosRecebidos(String id) { return blocos.get(id).keySet(); }
        public long bytesRecebidos(String id) { return blocos.get(id).values().stream().mapToLong(b -> b.length).sum(); }
        public Path montar(String id) {
            try {
                Path t = Files.createTempFile("uptest", ".bin");
                try (OutputStream os = Files.newOutputStream(t)) { for (byte[] b : blocos.get(id).values()) os.write(b); }
                return t;
            } catch (IOException e) { throw new UncheckedIOException(e); }
        }
        public void remover(String id) { remocoes++; metas.remove(id); blocos.remove(id); }
        public List<String> idsExistentes() { return new ArrayList<>(metas.keySet()); }
    }

    private static IniciarUploadComando cmd() {
        return new IniciarUploadComando("/amb", "supervisor", "127.0.0.1", "wdoc", "PostDocumento", "POST",
                "{}", "arq.pdf", 8L, 1024);
    }

    private static UploadChunkadoService servico(FakeStaging staging, EnviarDocumentoUseCase envio) {
        return new UploadChunkadoService(staging, envio, 1_000_000L, 1024, Set.of("pdf"));
    }

    @Test
    void abortar_removeStaging() {
        FakeStaging staging = new FakeStaging();
        UploadChunkadoService svc = servico(staging, arquivos -> List.of("{\"success\":true}"));
        ResultadoIniciarUpload r = svc.iniciar(cmd());
        svc.receberBloco(r.uploadId(), 0, new byte[]{1, 2, 3});
        assertFalse(staging.idsExistentes().isEmpty(), "staging deve existir antes do abort");
        svc.abortar(r.uploadId());
        assertTrue(staging.idsExistentes().isEmpty(), "abortar() deve remover o staging");
        assertEquals(1, staging.remocoes);
    }

    @Test
    void concluir_comFalhaNoPipeline_aindaLimpaOStaging() {
        FakeStaging staging = new FakeStaging();
        // pipeline (envio) que FALHA -> simula falha durante a conclusao do upload
        EnviarDocumentoUseCase envioQuebra = arquivos -> { throw new RuntimeException("falha simulada no wdoc"); };
        UploadChunkadoService svc = servico(staging, envioQuebra);
        ResultadoIniciarUpload r = svc.iniciar(cmd());
        svc.receberBloco(r.uploadId(), 0, new byte[]{1, 2, 3, 4, 5, 6, 7, 8});
        // a conclusao deve PROPAGAR a falha...
        assertThrows(RuntimeException.class, () -> svc.concluir(r.uploadId()));
        // ...mas o staging deve ter sido removido mesmo assim (finally) -> sem temporario orfao (2.9.7)
        assertTrue(staging.idsExistentes().isEmpty(), "mesmo em falha, o staging deve ser removido (finally)");
        assertEquals(1, staging.remocoes);
    }
}
