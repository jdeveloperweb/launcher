package com.prognum.scci.acesso.dominio.model;

import java.util.List;

/**
 * Senha atual + as 5 anteriores (NO_SENHA1..5), todas hashes md5crypt.
 * Copia do SccPasswordRepository.Senhas do launcher SCCI (legado).
 */
public record HistoricoSenhas(String atual, List<String> anteriores) {
}
