package com.prognum.launcher.documentos.chunked;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.prognum.launcher.documentos.model.UploadChunkado;
import com.prognum.launcher.documentos.port.out.RepositorioUploadChunked;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Doc Final de Requisitos (Upload/Download): tolerância a falhas / limpeza de temporários — remove
 * staging de uploads abandonados (cliente caiu, nunca chamou concluir/abortar) após
 * {@code max-idade-minutos}. Sem isso, uploads interrompidos vazariam disco indefinidamente.
 */
@Component
public class LimpezaUploadStagingJob {

    private static final Logger log = LoggerFactory.getLogger(LimpezaUploadStagingJob.class);

    private final RepositorioUploadChunked staging;
    private final long maxIdadeMs;

    public LimpezaUploadStagingJob(RepositorioUploadChunked staging,
            @Value("${launcher.documentos.chunked.limpeza.max-idade-minutos:240}") long maxIdadeMinutos) {
        this.staging = staging;
        this.maxIdadeMs = maxIdadeMinutos * 60_000L;
    }

    @Scheduled(fixedDelayString = "${launcher.documentos.chunked.limpeza.intervalo-ms:900000}")
    public void limpar() {
        long agora = System.currentTimeMillis();
        int removidos = 0;
        for (String id : staging.idsExistentes()) {
            UploadChunkado meta = staging.metadados(id).orElse(null);
            boolean expirado = meta == null || (agora - meta.criadoEmEpochMs()) > maxIdadeMs;
            if (expirado) {
                staging.remover(id);
                removidos++;
            }
        }
        if (removidos > 0) {
            log.info("upload_chunked_limpeza", kv("removidos", removidos));
        }
    }
}
