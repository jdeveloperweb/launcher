# scci-core — a MESMA imagem roda os dois trilhos Java do Strangler (README):
#   PURO    (SERVER_PORT=8092, SCCI_SDK=false) — 100% Java, stateless
#   HIBRIDO (SERVER_PORT=8090, SCCI_SDK=true)  — Java + Pascal via launcher-sdk (JNA/UDS+shim)
#
# BUILD SELF-CONTAINED (multi-stage): compila o jar A PARTIR DO FONTE e empacota o runtime.
#   CONTEXTO do build = RAIZ do monorepo (parent pom + modulos), NAO esta pasta.
#   Na mao (rode NA RAIZ do repo):
#     docker build -f scci-core/bootstrap/Dockerfile -t scci-core:local .
#   Ou:  docker compose -f deploy/docker/docker-compose.yml build scci-core-puro
#
# glibc (nao Alpine): o modo HIBRIDO usa JNA (posix_spawn/socketpair) contra o shim nativo
# /u/scci/binfpc/oserver-shim, que espera glibc — musl quebra essas chamadas nativas.

# ---------- stage 1: build (Maven) ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY . .
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -ntp -pl scci-core/bootstrap -am -DskipTests package

# ---------- stage 2: runtime ----------
FROM eclipse-temurin:21-jre-jammy

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r scci && useradd -r -g scci -d /app scci

WORKDIR /app
COPY --from=build /src/scci-core/bootstrap/target/scci-core.jar app.jar
RUN chown -R scci:scci /app
USER scci

# Documentacional: a porta efetiva vem de SERVER_PORT (precedencia sobre o server.port do yml).
# 8090 = hibrido, 8092 = puro.
EXPOSE 8090 8092

HEALTHCHECK --interval=15s --timeout=3s --start-period=40s --retries=5 \
    CMD wget -qO- "http://localhost:${SERVER_PORT:-8090}/actuator/health" | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
