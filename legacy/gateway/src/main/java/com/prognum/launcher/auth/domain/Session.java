package com.prognum.launcher.auth.domain;

import java.time.Instant;

/** Sessao (RF02): token autentico, separado da senha; com TTL e ultimo uso. */
public record Session(
        String token,
        String usuario,
        String ambiente,
        String ip,
        Instant criadoEm,
        Instant expiraEm
) {
}
