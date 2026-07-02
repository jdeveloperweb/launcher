package com.prognum.launcher.licencas.port.in;

import com.prognum.launcher.licencas.model.Licenca;

import java.util.List;

/**
 * SCAFFOLD (port de entrada) do contexto LICENCAS. Sem implementacao — a regra sera definida.
 * Enquanto isso o adapter REST responde 501 (Not Implemented).
 */
public interface ConsultarLicencasUseCase {

    List<Licenca> listar(String ambiente);
}
