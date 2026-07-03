package com.prognum.scci.documentos.application;

import com.prognum.scci.documentos.domain.port.in.GerenciarEstrutura;
import com.prognum.scci.documentos.domain.port.out.EstruturaDocumento;

/** Renomear / criar pasta (PutNome/PutPasta) — delega ao {@link EstruturaDocumento}. POJO puro. */
public class GerenciarEstruturaService implements GerenciarEstrutura {

    private final EstruturaDocumento estrutura;

    public GerenciarEstruturaService(EstruturaDocumento estrutura) {
        this.estrutura = estrutura;
    }

    @Override
    public void renomear(int id, String novoNome, String ambiente) {
        if (novoNome == null || novoNome.isBlank()) {
            throw new IllegalArgumentException("Nome invalido.");
        }
        estrutura.renomear(id, novoNome, ambiente);
    }

    @Override
    public int criarPasta(int idPai, String nome, boolean exibePastas, String ambiente) {
        if (nome == null || nome.isBlank()) {
            throw new IllegalArgumentException("Nome da pasta invalido.");
        }
        return estrutura.criarPasta(idPai, nome, exibePastas, ambiente);
    }
}
