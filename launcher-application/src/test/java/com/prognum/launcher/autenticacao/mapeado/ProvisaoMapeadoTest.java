package com.prognum.launcher.autenticacao.mapeado;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.prognum.launcher.autenticacao.model.ResultadoLogin;
import com.prognum.comum.cripto.WcopCrypto;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Testa as estratégias de provisionamento (família B) contra um fake do port, garantindo que cada
 * cliente decide como o loginXXX.pas correspondente. Usa {@link #webCrypt} (inverso de WcopCrypto.webDeCrypt)
 * para montar o segredo cifrado que o front enviaria.
 */
class ProvisaoMapeadoTest {

    private static final String AMB = "/tmp/amb";
    private static final String TOKEN = "TOKENFIXO";
    private FakeProvisionamento repo;

    @BeforeEach
    void setup() {
        repo = new FakeProvisionamento();
    }

    /** Inverso exato de WcopCrypto.webDeCrypt: gera o WebCrypt de um texto claro. */
    static String webCrypt(String plain) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < plain.length(); i++) {
            int p = i + 1;
            int orig = plain.charAt(i) & 0xFF;
            int ch = ((((orig + p * 5) & 0xFF) ^ 0x96) & 0xFF);
            sb.append((char) (((ch >> 4) & 0x0F) + 65));
            sb.append((char) ((ch & 0x0F) + 65));
        }
        return sb.toString();
    }

    private static String xml(String perfil) {
        return webCrypt("!#___<r><perfil>" + perfil + "</perfil><ipAddr>1.2.3.4</ipAddr>"
                + "<expiresIn>60</expiresIn><token>t</token></r>");
    }

    @Test
    void webCrypt_e_o_inverso_do_webDeCrypt() {
        assertThat(WcopCrypto.webDeCrypt(webCrypt("!#___ola mundo 123"))).isEqualTo("!#___ola mundo 123");
    }

    // -------------------------------------------------------------- direto
    @Test
    void direto_usuario_existente_devolve_grafia_real() {
        repo.usuarios.put("JOAO", new UsuarioScci("Joao", 1, "ADM", null));
        DadosProvisao d = new ProvisaoDireto(repo).provisiona("joao@empresa.com", "x", AMB, "ip", TOKEN);
        assertThat(d.usuarioEfetivo()).isEqualTo("Joao");
        assertThat(d.sessionToken()).isEqualTo(TOKEN);
    }

    @Test
    void direto_sem_arroba_e_negado() {
        assertThatThrownBy(() -> new ProvisaoDireto(repo).provisiona("joao", "x", AMB, "ip", TOKEN))
                .isInstanceOf(RuntimeException.class);
    }

    @Test
    void direto_usuario_inexistente_e_negado() {
        assertThatThrownBy(() -> new ProvisaoDireto(repo).provisiona("nao@x.com", "x", AMB, "ip", TOKEN))
                .hasMessageContaining("nao cadastrado");
    }

    // -------------------------------------------------------------- brb
    @Test
    void brb_atualiza_perfil_quando_muda() {
        repo.usuarios.put("MARIA", new UsuarioScci("maria", 10, "ANTIGO", null));
        repo.perfilPorNome.put("GESTOR", 20);
        DadosProvisao d = new ProvisaoBrb(repo).provisiona("maria", xml("GESTOR"), AMB, "ip", TOKEN);
        assertThat(d.usuarioEfetivo()).isEqualTo("maria");
        assertThat(repo.perfisAtualizados).containsEntry("maria", 20);
    }

    @Test
    void brb_nao_atualiza_quando_perfil_igual() {
        repo.usuarios.put("MARIA", new UsuarioScci("maria", 20, "GESTOR", null));
        repo.perfilPorNome.put("GESTOR", 20);
        new ProvisaoBrb(repo).provisiona("maria", xml("GESTOR"), AMB, "ip", TOKEN);
        assertThat(repo.perfisAtualizados).isEmpty();
    }

    @Test
    void brb_usuario_inexistente_e_negado() {
        repo.perfilPorNome.put("GESTOR", 20);
        assertThatThrownBy(() -> new ProvisaoBrb(repo).provisiona("x", xml("GESTOR"), AMB, "ip", TOKEN))
                .hasMessageContaining("nao cadastrado");
    }

    @Test
    void brb_perfil_sem_acesso_e_negado() {
        repo.usuarios.put("MARIA", new UsuarioScci("maria", 10, "ANTIGO", null));
        assertThatThrownBy(() -> new ProvisaoBrb(repo).provisiona("maria", xml("INEXISTENTE"), AMB, "ip", TOKEN))
                .hasMessageContaining("acesso");
    }

    // -------------------------------------------------------------- cashmeweb
    @Test
    void cashmeweb_cpf_com_contrato_entra_como_usuarioweb() {
        repo.contratosCpf.add("00000012345678");   // completado p/ 14
        DadosProvisao d = new ProvisaoCashmeweb(repo).provisiona("12345678", "ignorado", AMB, "ip", TOKEN);
        assertThat(d.usuarioEfetivo()).isEqualTo("usuarioweb:");
    }

    @Test
    void cashmeweb_cpf_sem_contrato_e_negado() {
        assertThatThrownBy(() -> new ProvisaoCashmeweb(repo).provisiona("12345678", "x", AMB, "ip", TOKEN))
                .hasMessageContaining("contratos");
    }

    @Test
    void cashmeweb_email_valida_perfil() {
        repo.usuarios.put("ANA", new UsuarioScci("Ana", 1, "X", null));
        repo.perfilPorNome.put("OPERADOR", 5);
        DadosProvisao d = new ProvisaoCashmeweb(repo).provisiona("ana@x.com", xml("OPERADOR"), AMB, "ip", TOKEN);
        assertThat(d.usuarioEfetivo()).isEqualTo("Ana");
        assertThat(repo.perfisAtualizados).containsEntry("Ana", 5);
    }

    // -------------------------------------------------------------- c6
    @Test
    void c6_provisiona_novo_usuario_com_email_ad() {
        repo.perfilPorNome.put("ADMIN", 7);
        repo.entidadeDefault = 3;
        repo.setores.put("7:3", "SET1");
        DadosProvisao d = new ProvisaoC6(repo).provisiona("carlos@banco.com", xml("ADMIN"), AMB, "ip", TOKEN);
        assertThat(d.usuarioEfetivo()).isEqualTo("carlos");
        assertThat(repo.inseridos).hasSize(1);
        NovoUsuario ins = repo.inseridos.get(0);
        assertThat(ins.usuario()).isEqualTo("carlos");
        assertThat(ins.perfPrimario()).isEqualTo(7);
        assertThat(ins.entPrimaria()).isEqualTo(3);
        assertThat(ins.coSetor()).isEqualTo("SET1");
        assertThat(ins.noAutenticacaoAd()).isEqualTo("carlos@banco.com");
        assertThat(ins.senhaToken()).isNull();   // c6 não grava SENHA
    }

    @Test
    void c6_atualiza_perfil_e_emailad_de_usuario_existente() {
        repo.usuarios.put("CARLOS", new UsuarioScci("carlos", 1, "OLD", "antigo@x.com"));
        repo.perfilPorNome.put("ADMIN", 7);
        new ProvisaoC6(repo).provisiona("carlos@banco.com", xml("ADMIN"), AMB, "ip", TOKEN);
        assertThat(repo.perfisAtualizados).containsEntry("carlos", 7);
        assertThat(repo.emailsAdAtualizados).containsEntry("carlos", "carlos@banco.com");
        assertThat(repo.inseridos).isEmpty();
    }

    @Test
    void c6_perfil_sem_acesso_e_negado() {
        assertThatThrownBy(() -> new ProvisaoC6(repo).provisiona("c@x.com", xml("NAO"), AMB, "ip", TOKEN))
                .hasMessageContaining("acesso");
    }

    // -------------------------------------------------------------- itau
    @Test
    void itau_insere_quando_nao_existe() {
        repo.perfilPorNome.put("GRUPOX", 9);
        repo.perfisExistentes.add(9);
        repo.entidadeDefault = 2;
        DadosProvisao d = new ProvisaoItau(repo).provisiona("pedro", webCrypt("!#___GRUPOX"), AMB, "ip", TOKEN);
        assertThat(d.usuarioEfetivo()).isNull();   // itau não corrige grafia
        assertThat(repo.inseridos).hasSize(1);
        assertThat(repo.inseridos.get(0).senhaToken()).isEqualTo(TOKEN);
    }

    @Test
    void itau_atualiza_quando_existe() {
        repo.perfilPorNome.put("GRUPOX", 9);
        repo.entidadeDefault = 2;
        repo.usuariosOuEmail.add("pedro");
        new ProvisaoItau(repo).provisiona("pedro", webCrypt("!#___GRUPOX"), AMB, "ip", TOKEN);
        assertThat(repo.provisoesAtualizadas).containsExactly("pedro");
        assertThat(repo.inseridos).isEmpty();
    }

    @Test
    void itau_perfil_inexistente_e_negado() {
        assertThatThrownBy(() -> new ProvisaoItau(repo).provisiona("pedro", webCrypt("!#___NAO"), AMB, "ip", TOKEN))
                .hasMessageContaining("Perfil");
    }

    @Test
    void itau_prefixo_invalido_e_senha_incorreta() {
        assertThatThrownBy(() -> new ProvisaoItau(repo).provisiona("pedro", webCrypt("XXXXXGRUPOX"), AMB, "ip", TOKEN))
                .hasMessageContaining("Senha incorreta");
    }

    // -------------------------------------------------------------- ailos
    @Test
    void ailos_insere_usuario_de_cooperativa() {
        // memberof=0012...045 -> cooperativa "0012", perfil "045"; office sem PA -> ent "12"+"00000"
        repo.entidadePorLogin.put("1200000", 88);
        repo.entidadesExistentes.add(88);
        repo.perfisExistentes.add(45);
        String segredo = webCrypt("!#___memberof=0012XY045,Givename=Beltrano,PhysicalDeliveryOfficeName=SEDE");
        DadosProvisao d = new ProvisaoAilos(repo).provisiona("beltrano", segredo, AMB, "ip", TOKEN);
        assertThat(d.usuarioEfetivo()).isNull();
        assertThat(repo.inseridos).hasSize(1);
        NovoUsuario ins = repo.inseridos.get(0);
        assertThat(ins.perfPrimario()).isEqualTo(45);
        assertThat(ins.entPrimaria()).isEqualTo(88);
        assertThat(ins.entSecundaria()).isNull();
        assertThat(ins.nome()).isEqualTo("Beltrano");
        assertThat(ins.coSetor()).isEqualTo("1");
    }

    @Test
    void ailos_nao_insere_se_ja_existe() {
        repo.entidadePorLogin.put("1200000", 88);
        repo.entidadesExistentes.add(88);
        repo.perfisExistentes.add(45);
        repo.usuariosOuEmail.add("beltrano");
        String segredo = webCrypt("!#___memberof=0012XY045,Givename=Beltrano,PhysicalDeliveryOfficeName=SEDE");
        new ProvisaoAilos(repo).provisiona("beltrano", segredo, AMB, "ip", TOKEN);
        assertThat(repo.inseridos).isEmpty();
    }

    @Test
    void ailos_perfil_inexistente_e_negado() {
        repo.entidadePorLogin.put("1200000", 88);
        repo.entidadesExistentes.add(88);
        String segredo = webCrypt("!#___memberof=0012XY045,Givename=B,PhysicalDeliveryOfficeName=SEDE");
        assertThatThrownBy(() -> new ProvisaoAilos(repo).provisiona("b", segredo, AMB, "ip", TOKEN))
                .hasMessageContaining("Perfil");
    }

    // -------------------------------------------------------------- unicred
    @Test
    void unicred_usuario_existente_e_subordinado_ok() {
        repo.usuariosOuEmail.add("nome.sobrenome.0060");
        repo.entPrimariaDoUsuario.put("nome.sobrenome.0060", 60);
        String segredo = webCrypt("!#___jwt_id_identifier=nome.sobrenome.0060,token_tag=abc");
        DadosProvisao d = new ProvisaoUnicred(repo).provisiona("ignorado", segredo, AMB, "ip", TOKEN);
        assertThat(d.usuarioEfetivo()).isEqualTo("nome.sobrenome.0060");
    }

    @Test
    void unicred_nao_subordinado_e_negado() {
        repo.usuariosOuEmail.add("nome.sobrenome.0060");
        repo.entPrimariaDoUsuario.put("nome.sobrenome.0060", 99);   // não é 60
        String segredo = webCrypt("!#___jwt_id_identifier=nome.sobrenome.0060,token_tag=abc");
        assertThatThrownBy(() -> new ProvisaoUnicred(repo).provisiona("x", segredo, AMB, "ip", TOKEN))
                .hasMessageContaining("subordinado");
    }

    @Test
    void unicred_usuario_inexistente_e_negado() {
        repo.entPrimariaDoUsuario.put("nome.sobrenome.0060", 60);
        String segredo = webCrypt("!#___jwt_id_identifier=nome.sobrenome.0060,token_tag=abc");
        assertThatThrownBy(() -> new ProvisaoUnicred(repo).provisiona("x", segredo, AMB, "ip", TOKEN))
                .hasMessageContaining("nao cadastrado");
    }

    // -------------------------------------------------------------- AutenticadorMapeado
    @Test
    void autenticador_sucesso_emite_T_com_token_e_usuario_efetivo() {
        repo.usuarios.put("JOAO", new UsuarioScci("Joao", 1, "ADM", null));
        AutenticadorMapeado a = new AutenticadorMapeado(new ProvisaoDireto(repo), () -> TOKEN);
        ResultadoLogin r = a.autenticar("joao@x.com", "x", AMB, "ip");
        assertThat(r.sucesso()).isTrue();
        assertThat(r.codErro()).isEqualTo('T');
        assertThat(r.sessionKey()).isEqualTo(TOKEN);
        assertThat(r.usuarioEfetivo()).isEqualTo("Joao");
        assertThat(a.metodo()).isEqualTo(ProvisaoDireto.METODO);
    }

    @Test
    void autenticador_erro_de_provisionamento_vira_F_com_mensagem() {
        AutenticadorMapeado a = new AutenticadorMapeado(new ProvisaoDireto(repo), () -> TOKEN);
        ResultadoLogin r = a.autenticar("nao@x.com", "x", AMB, "ip");
        assertThat(r.sucesso()).isFalse();
        assertThat(r.codErro()).isEqualTo('F');
        assertThat(r.mensagem()).contains("nao cadastrado");
        assertThat(r.sessionKey()).isNull();
    }
}
