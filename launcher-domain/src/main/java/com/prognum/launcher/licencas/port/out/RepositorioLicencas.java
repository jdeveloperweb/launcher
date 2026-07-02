package com.prognum.launcher.licencas.port.out;

import com.prognum.launcher.licencas.model.Licenca;

import java.util.List;

/** SCAFFOLD (port de saida) do contexto LICENCAS. Fonte de dados a definir (banco do ambiente?). */
public interface RepositorioLicencas {

    List<Licenca> listar(String ambiente);
}
