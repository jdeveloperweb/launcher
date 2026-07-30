package com.prognum.scci;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Evidência de execução JAVA PURA. Para CADA operação atendida por um MÓDULO Java do scci-core
 * (acesso, documentos, sessao, ...), loga um marcador {@code java_puro} dizendo QUAL módulo executou —
 * deixando explícito que rodou em Java puro, sem Pascal.
 *
 * <p>O caminho HÍBRIDO ({@link ExecutorHibridoController}, que roda Pascal via o launcher-sdk) fica de
 * fora: ele está no pacote raiz {@code com.prognum.scci} e já loga {@code sdk_hibrido_*}.</p>
 */
@Configuration
class ModuloJavaLogConfig implements WebMvcConfigurer {

    private static final Logger log = LoggerFactory.getLogger("java-puro");

    private static final String T0 = ModuloJavaLogConfig.class.getName() + ".t0";

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override
            public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
                if (handler instanceof HandlerMethod hm && moduloDe(hm.getBeanType().getPackageName()) != null) {
                    req.setAttribute(T0, System.nanoTime());   // cronometra o tempo do módulo Java (self-time)
                }
                return true;
            }

            @Override
            public void afterCompletion(HttpServletRequest req, HttpServletResponse res, Object handler, Exception ex) {
                Object t0 = req.getAttribute(T0);
                if (!(handler instanceof HandlerMethod hm) || t0 == null) {
                    return;
                }
                String modulo = moduloDe(hm.getBeanType().getPackageName());
                long ms = (System.nanoTime() - (Long) t0) / 1_000_000;
                // Evidência de Java puro COM o tempo próprio do módulo (sem Pascal) — alimenta o RTT.
                log.info("java_puro", kv("modulo", modulo), kv("operacao", hm.getMethod().getName()),
                        kv("via", "java-puro"), kv("ms", ms), kv("status", res.getStatus()),
                        kv("erro", ex != null || res.getStatus() >= 400));
            }
        });
    }

    /** {@code com.prognum.scci.<modulo>.*} -> "<modulo>"; raiz {@code com.prognum.scci} (híbrido Pascal) -> null. */
    private static String moduloDe(String pkg) {
        String base = "com.prognum.scci.";
        if (pkg == null || !pkg.startsWith(base)) {
            return null;   // actuator, híbrido (pacote raiz), etc. — não é módulo Java de domínio
        }
        String rest = pkg.substring(base.length());
        int dot = rest.indexOf('.');
        String m = dot < 0 ? rest : rest.substring(0, dot);
        return m.isEmpty() ? null : m;
    }
}
