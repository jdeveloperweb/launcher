package com.prognum.launcher.autenticacao.mapeado;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import com.prognum.launcher.autenticacao.port.out.ProvisionamentoUsuario;

/** Fake em memória do port de provisionamento — deixa testar as estratégias sem banco. */
class FakeProvisionamento implements ProvisionamentoUsuario {

    final Map<String, UsuarioScci> usuarios = new HashMap<>();        // chave = UPPER(usuario)
    final Set<String> usuariosOuEmail = new HashSet<>();              // existência p/ buscarPorUsuarioOuEmail
    final Map<String, Integer> perfilPorNome = new HashMap<>();       // UPPER(nome) -> cod
    final Set<Integer> perfisExistentes = new HashSet<>();
    final Set<Integer> entidadesExistentes = new HashSet<>();
    final Map<String, Integer> entidadePorLogin = new HashMap<>();    // coEntLogin -> co_entidade
    final Map<String, String> setores = new HashMap<>();             // "cod:ent" -> setor
    final Set<String> contratosCpf = new HashSet<>();
    final Map<String, Integer> entPrimariaDoUsuario = new HashMap<>();
    final Map<String, Integer> entSecundariaDoUsuario = new HashMap<>();

    int entidadeDefault = -1;
    boolean entidadeDefaultAusente = false;
    boolean entidadeDefaultNaoNumerica = false;

    // gravações para asserção
    final List<NovoUsuario> inseridos = new ArrayList<>();
    final Map<String, Integer> perfisAtualizados = new HashMap<>();
    final Map<String, String> emailsAdAtualizados = new HashMap<>();
    final List<String> provisoesAtualizadas = new ArrayList<>();

    @Override
    public Optional<Integer> perfilPorNome(String nomePerfil, boolean exato, String ambiente) {
        return Optional.ofNullable(perfilPorNome.get(nomePerfil.toUpperCase()));
    }

    @Override
    public boolean perfilExiste(int codPerfil, String ambiente) {
        return perfisExistentes.contains(codPerfil);
    }

    @Override
    public Optional<UsuarioScci> buscarPorUsuario(String usuario, String ambiente) {
        return Optional.ofNullable(usuarios.get(usuario.toUpperCase()));
    }

    @Override
    public Optional<UsuarioScci> buscarPorUsuarioOuEmail(String usuario, String ambiente) {
        return usuariosOuEmail.contains(usuario)
                ? Optional.of(new UsuarioScci(usuario, null, null, null)) : Optional.empty();
    }

    @Override
    public void atualizarPerfil(String usuario, int codPerfil, String ambiente) {
        perfisAtualizados.put(usuario, codPerfil);
    }

    @Override
    public void atualizarEmailAd(String usuario, String emailAd, String ambiente) {
        emailsAdAtualizados.put(usuario, emailAd);
    }

    @Override
    public void atualizarProvisao(String usuario, int perfPrimario, int entPrimaria, String coSetor,
                                  String nome, String ambiente) {
        provisoesAtualizadas.add(usuario);
    }

    @Override
    public void inserir(NovoUsuario novo, String ambiente) {
        inseridos.add(novo);
    }

    @Override
    public int entidadeDefault(String ambiente) {
        if (entidadeDefaultAusente) {
            throw new IllegalStateException("ENTIDADEUSUARIODEFAULT ausente");
        }
        return entidadeDefault;
    }

    @Override
    public int entidadeDefaultOuMenos1(String ambiente) {
        if (entidadeDefaultAusente) {
            return -1;
        }
        if (entidadeDefaultNaoNumerica) {
            throw new IllegalStateException("ENTIDADEUSUARIODEFAULT configurado errado");
        }
        return entidadeDefault;
    }

    @Override
    public boolean entidadeExiste(int codEnt, String ambiente) {
        return entidadesExistentes.contains(codEnt);
    }

    @Override
    public int entidadePorEntidadeLogin(String coEntidadeLogin, String ambiente) {
        return entidadePorLogin.getOrDefault(coEntidadeLogin, -1);
    }

    @Override
    public String obterSetor(int codPerfil, int codEntidade, String ambiente) {
        return setores.getOrDefault(codPerfil + ":" + codEntidade, "");
    }

    @Override
    public boolean usuarioSubordinadoAEntidade(String usuario, String entidadeInformada, String ambiente) {
        if (entidadeInformada == null || entidadeInformada.isBlank()) {
            return true;
        }
        int alvo;
        try {
            alvo = Integer.parseInt(entidadeInformada.trim());
        } catch (NumberFormatException e) {
            return false;
        }
        return Integer.valueOf(alvo).equals(entPrimariaDoUsuario.get(usuario))
                || Integer.valueOf(alvo).equals(entSecundariaDoUsuario.get(usuario));
    }

    @Override
    public boolean existeContratoCpf(String cpf, String ambiente) {
        return contratosCpf.contains(cpf);
    }
}
