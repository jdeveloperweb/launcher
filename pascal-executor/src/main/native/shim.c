/* =====================================================================
 *  shim.c — Alt4 (UDS + shim) do transporte v2 do oserver.
 *
 *  NÃO toca em NENHUM programa Pascal. Ele apenas:
 *    1) conecta no UDS recebido em argv[1];
 *    2) envia o token (env OSERVER_TOKEN) — handshake que prova ser o filho esperado;
 *    3) faz dup2 do socket para o FD 6;
 *    4) dá exec no programa 'w' ORIGINAL (argv[2..]), que vê o FD 6 IDÊNTICO ao socketpair de hoje.
 *
 *  Uso:  shim <uds_path> <programa> 6 6 <ip>      (env: OSERVER_TOKEN=<hex>)
 *  Build (na box Linux):  cc -O2 -o oserver-shim shim.c
 * ===================================================================== */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

#define FD_OSERVER 6

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "uso: shim <uds_path> <programa> [args...]\n");
        return 2;
    }
    const char *uds = argv[1];
    const char *token = getenv("OSERVER_TOKEN");
    if (!token || !*token) {
        fprintf(stderr, "shim: OSERVER_TOKEN ausente\n");
        return 3;
    }

    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s < 0) { perror("shim socket"); return 4; }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, uds, sizeof(addr.sun_path) - 1);
    if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) { perror("shim connect"); return 5; }

    /* handshake: envia o token (o lado Java lê e confere antes de mandar o request) */
    size_t tlen = strlen(token);
    ssize_t off = 0;
    while ((size_t)off < tlen) {
        ssize_t w = write(s, token + off, tlen - off);
        if (w <= 0) { perror("shim write token"); return 6; }
        off += w;
    }

    /* entrega o socket ao programa no FD 6 (dup2 limpa o CLOEXEC) */
    if (s != FD_OSERVER) {
        if (dup2(s, FD_OSERVER) < 0) { perror("shim dup2"); return 7; }
        close(s);
    }

    /* exec do programa ORIGINAL — argv[2..] = programa + args (6 6 <ip>). Herda o env atual (do launcher). */
    execv(argv[2], &argv[2]);
    perror("shim execv");   /* só chega aqui se o exec falhar */
    return 127;
}
