# launcher — trilho "pascal" do Strangler (README): executor Pascal standalone (:8091),
# ancora legada enquanto operacoes nao migram para o scci-core (puro/hibrido).
# Build (fora do Docker): mvn -DskipTests clean package  (gera target/launcher.jar)
# Build da imagem, a partir desta pasta:
#   docker build -t launcher:local .
#
# glibc (nao Alpine): usa o launcher-sdk (JNA: posix_spawn/socketpair) contra o shim nativo
# /u/scci/binfpc/oserver-shim, que espera glibc.
FROM eclipse-temurin:21-jre-jammy

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r scci && useradd -r -g scci -d /app scci

WORKDIR /app
COPY target/launcher.jar app.jar
RUN chown -R scci:scci /app
USER scci

EXPOSE 8091

HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=5 \
    CMD wget -qO- "http://localhost:${SERVER_PORT:-8091}/actuator/health" | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
