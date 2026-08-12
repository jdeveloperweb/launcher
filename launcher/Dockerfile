# launcher — trilho "pascal" do Strangler (README): executor Pascal standalone (:8091),
# ancora legada enquanto operacoes nao migram para o scci-core (puro/hibrido).
#
# BUILD SELF-CONTAINED (multi-stage): compila o jar A PARTIR DO FONTE e empacota o runtime.
#   CONTEXTO do build = RAIZ do monorepo (parent pom + modulos), NAO esta pasta.
#   Na mao (rode NA RAIZ do repo):
#     docker build -f launcher/Dockerfile -t launcher:local .
#   Ou:  docker compose -f deploy/docker/docker-compose.yml build launcher
#
# glibc (nao Alpine): usa o launcher-sdk (JNA: posix_spawn/socketpair) contra o shim nativo
# /u/scci/binfpc/oserver-shim, que espera glibc.

# ---------- stage 1: build (Maven) ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY . .
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -ntp -pl launcher -am -DskipTests package

# ---------- stage 2: runtime ----------
FROM eclipse-temurin:21-jre-jammy

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r scci && useradd -r -g scci -d /app scci

WORKDIR /app
COPY --from=build /src/launcher/target/launcher.jar app.jar
RUN chown -R scci:scci /app
USER scci

EXPOSE 8091

HEALTHCHECK --interval=15s --timeout=3s --start-period=40s --retries=5 \
    CMD wget -qO- "http://localhost:${SERVER_PORT:-8091}/actuator/health" | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
