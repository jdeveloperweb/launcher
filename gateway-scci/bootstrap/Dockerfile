# gateway-scci — reator/orquestrador do Strangler (README): roteia entre o scci-core (Java) e o
# pascal-executor (legado), na porta 8083 (atras do Kong, na 8082, que o Apache proxya).
# Build (fora do Docker): mvn -DskipTests clean package  (gera target/gateway-scci.jar)
# Build da imagem, a partir desta pasta:
#   docker build -t gateway-scci:local .
#
# Sem JNA/chamada nativa (nao fala com o Pascal direto): so orquestra scci-core e pascal-executor
# via REST. glibc por consistencia com os demais trilhos, mas nao e um requisito funcional aqui.
FROM eclipse-temurin:21-jre-jammy

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r scci && useradd -r -g scci -d /app scci

WORKDIR /app
COPY target/gateway-scci.jar app.jar
RUN chown -R scci:scci /app
USER scci

EXPOSE 8083

HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=5 \
    CMD wget -qO- "http://localhost:${SERVER_PORT:-8083}/actuator/health" | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
