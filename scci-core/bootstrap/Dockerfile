# scci-core — mesma imagem roda os dois trilhos Java do Strangler (README):
#   PURO    (SERVER_PORT=8092, SCCI_SDK=false) — 100% Java, stateless
#   HIBRIDO (SERVER_PORT=8090, SCCI_SDK=true)  — Java + Pascal via launcher-sdk (JNA/UDS+shim)
# Build (fora do Docker): mvn -DskipTests clean package  (gera target/scci-core.jar)
# Build da imagem, a partir desta pasta:
#   docker build -t scci-core:local .
#
# glibc (nao Alpine): o modo HIBRIDO usa JNA (posix_spawn/socketpair) contra o shim nativo
# /u/scci/binfpc/oserver-shim, que espera glibc — musl quebra essas chamadas nativas.
FROM eclipse-temurin:21-jre-jammy

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r scci && useradd -r -g scci -d /app scci

WORKDIR /app
COPY target/scci-core.jar app.jar
RUN chown -R scci:scci /app
USER scci

# Documentacional: a porta efetiva vem de SERVER_PORT (precedencia sobre o server.port fixo
# do application.yml). 8090 = hibrido, 8092 = puro.
EXPOSE 8090 8092

HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=5 \
    CMD wget -qO- "http://localhost:${SERVER_PORT:-8090}/actuator/health" | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
