package com.prognum.launcher.compartilhado.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Observabilidade (RF09/RNF06): garante um request-id em toda requisicao (do header X-Request-Id
 * ou gerado — casa com o correlation-id do Kong), coloca no MDC (vai em todo log) e no header de
 * resposta, e emite um log de acesso com status e duracao. Infra COMPARTILHADA.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {

    public static final String HEADER = "X-Request-Id";
    private static final Logger log = LoggerFactory.getLogger("access");

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String id = req.getHeader(HEADER);
        if (id == null || id.isBlank()) {
            id = UUID.randomUUID().toString();
        }
        MDC.put("requestId", id);
        res.setHeader(HEADER, id);
        long inicio = System.nanoTime();
        try {
            chain.doFilter(req, res);
        } finally {
            long ms = (System.nanoTime() - inicio) / 1_000_000;
            log.info("http_request",
                    kv("metodo", req.getMethod()),
                    kv("path", req.getRequestURI()),
                    kv("status", res.getStatus()),
                    kv("duracaoMs", ms));
            MDC.remove("requestId");
        }
    }
}
