package com.prognum.launcher.autenticacao;

import com.prognum.launcher.autenticacao.port.out.ValidacaoAcessoRepository;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Validações de acesso CPF/protocolo (ValidaCpf/ValidaProtocolo do loginbd). Vazio = válido. */
class ValidacaoAcessoServiceTest {

    private final ValidacaoAcessoRepository repo = mock(ValidacaoAcessoRepository.class);
    private final ValidacaoAcessoService svc = new ValidacaoAcessoService(repo);

    @Test
    void cpf_vazio_e_valido_sem_consultar() {
        assertThat(svc.cpfValido("", "/amb")).isTrue();
        assertThat(svc.cpfValido(null, "/amb")).isTrue();
        verify(repo, never()).cpfComOperacao(any(), any());
    }

    @Test
    void cpf_com_operacao_e_valido() {
        when(repo.cpfComOperacao("12345678901", "/amb")).thenReturn(true);
        assertThat(svc.cpfValido("12345678901", "/amb")).isTrue();
    }

    @Test
    void cpf_sem_operacao_e_invalido() {
        when(repo.cpfComOperacao("00000000000", "/amb")).thenReturn(false);
        assertThat(svc.cpfValido("00000000000", "/amb")).isFalse();
    }

    @Test
    void protocolo_vazio_valido_senao_delega() {
        assertThat(svc.protocoloValido("  ", "/amb")).isTrue();
        when(repo.protocoloExiste("998877", "/amb")).thenReturn(true);
        assertThat(svc.protocoloValido("998877", "/amb")).isTrue();
        when(repo.protocoloExiste("111", "/amb")).thenReturn(false);
        assertThat(svc.protocoloValido("111", "/amb")).isFalse();
    }
}
