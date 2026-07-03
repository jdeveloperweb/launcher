package com.prognum.scci.acesso.aplicacao.mapeado;

import com.prognum.scci.acesso.dominio.mapeado.DadosProvisao;

/**
 * A parte ESPECÍFICA de cada login payload-mapeado (o {@code ExecutaLoginXXX} do .pas): recebe o
 * segredo cifrado do IdP, decifra/parseia do jeito do cliente e provisiona o USUARIO, devolvendo a
 * grafia efetiva + o token. O que é COMUM (gerar token, montar a resposta, tratar erro como 'F') fica
 * no {@link AutenticadorMapeado}. Cada estratégia é um POJO fiel a um loginXXX.pas, testável com um
 * fake do {@code ProvisionamentoUsuario}.
 */
public interface EstrategiaProvisao {

    /** Id do método (casa com a config por ambiente), ex.: "MAPEADO_C6", "MAPEADO_ITAU". */
    String metodo();

    /**
     * Provisiona/valida o usuário e devolve a grafia efetiva. {@code segredo} = campo "senha" cifrado
     * (WebCrypt) vindo do front; {@code sessionToken} = token já gerado pelo coordenador (o legado usa
     * o mesmo valor no SENHA do INSERT e na SESSION_KEY). Lança exceção com a mensagem do legado quando
     * o acesso é negado (o {@link AutenticadorMapeado} converte em código 'F').
     */
    DadosProvisao provisiona(String usuario, String segredo, String ambiente, String ip, String sessionToken);
}
