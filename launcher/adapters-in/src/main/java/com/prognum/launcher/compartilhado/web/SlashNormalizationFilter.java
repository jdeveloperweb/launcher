package com.prognum.launcher.compartilhado.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Normaliza barras duplicadas no caminho (ex.: "//w/login" -> "/w/login").
 *
 * Por que: o proxy do Apache (ProxyPass /aejs-l/rest -> bootstrap) pode gerar "//" no inicio do
 * caminho. Sem normalizar, a requisicao nao casa com os handlers nativos (/w/login) e cai no
 * catch-all. Aqui colapsamos as barras e re-despachamos. Infra COMPARTILHADA.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class SlashNormalizationFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String uri = request.getRequestURI();
        String norm = uri.replaceAll("/{2,}", "/");
        if (!norm.equals(uri)) {
            request.getRequestDispatcher(norm).forward(request, response);   // re-mapeia no caminho limpo
            return;
        }
        chain.doFilter(request, response);
    }
}
