package com.prognum.scci.acesso.domain.port.out;

import java.util.Optional;

/**
 * Porta de saida: devolve a versao do SISTEMA (a constante {@code Versao}/{@code VersaoC} do {@code smv.pas},
 * COMPILADA no binario Pascal) — a fonte da verdade, NAO configuracao. Usada pelo check de versao do banco
 * no login (compara {@code VERSAO_INST.NU_VERSAO} contra esta).
 *
 * <p>O formato pode variar (compacto {@code "984"} ou pontuado {@code "9.84"}, conforme a fonte); quem compara
 * normaliza. {@link Optional#empty()} = nao foi possivel determinar (ex.: deploy PURO sem Pascal, ou falha ao
 * consultar) — nesse caso o check NAO bloqueia o login (fail-open).</p>
 */
public interface VersaoSistemaProvider {

    /** Versao do sistema para o ambiente (do binario Pascal daquele binfpc), ou vazio se indeterminavel. */
    Optional<String> versaoSistema(String ambiente);
}
