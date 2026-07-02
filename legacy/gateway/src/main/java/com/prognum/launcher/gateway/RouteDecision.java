package com.prognum.launcher.gateway;

/** Rotas do padrao Strangler (regras.md 0.3 / DA04). */
public enum RouteDecision {
    NATIVE_JAVA,     // (A) funcionalidade ja migrada para Java
    PROCESS_BUILDER, // (B) executa .exe Pascal via ProcessBuilder
    LEGACY_PROXY     // (C) proxy para o W_COP / launcher Pascal legado
}
