# gateway-scci — reator/orquestrador do Strangler (README): a borda (edge) na porta 8083
# (atras do Kong, na 8082/8000, que o Apache proxya). Java puro, sem chamada nativa.
#
# BUILD SELF-CONTAINED (multi-stage): compila o jar A PARTIR DO FONTE e empacota o runtime —
# NAO precisa de `mvn package` na maquina antes.
#   IMPORTANTE: como e um monorepo Maven, o CONTEXTO do build e a RAIZ do repo (parent pom +
#   modulos), NAO esta pasta. Por isso o compose usa `context: ../..` + `dockerfile: <path>`.
#   Na mao (rode NA RAIZ do repo):
#     docker build -f gateway-scci/bootstrap/Dockerfile -t gateway-scci:local .
#   Ou:  docker compose -f deploy/docker/docker-compose.yml build gateway-scci

# ---------- stage 1: build (Maven) ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
# copia o monorepo; o .dockerignore da raiz corta target/, .git, node_modules, qa-e2e, etc.
COPY . .
# compila SO este modulo + suas dependencias internas (-am). Cache do ~/.m2 entre builds (BuildKit).
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -ntp -pl gateway-scci/bootstrap -am -DskipTests package

# ---------- stage 2: runtime ----------
FROM eclipse-temurin:21-jre-jammy

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r scci && useradd -r -g scci -d /app scci

WORKDIR /app
COPY --from=build /src/gateway-scci/bootstrap/target/gateway-scci.jar app.jar
RUN chown -R scci:scci /app
USER scci

EXPOSE 8083

HEALTHCHECK --interval=15s --timeout=3s --start-period=40s --retries=5 \
    CMD wget -qO- "http://localhost:${SERVER_PORT:-8083}/actuator/health" | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
