# FHIR validator in server mode, for use as a test-bed component (GITB / ITB plugin).
#
# Build context must contain validator_cli.jar (the CLI jar this repository
# produces); the CI workflow stages it there after the Maven build:
#
#   docker build -t fhir-validator .
#   docker run -p 8080:8080 -v fhir-packages:/home/validator/.fhir fhir-validator
#
# Runtime configuration, all optional:
#   FHIR_VERSION       FHIR version the server validates against (default 5.0)
#   VALIDATOR_ARGS     extra arguments appended to the server command
#   JAVA_TOOL_OPTIONS  JVM options, e.g. -Xmx8g
#
# The package cache lives at /home/validator/.fhir; mount a volume there so
# downloaded IGs survive a container recreate. The directory exists in the
# image, owned by the validator user, so a fresh named volume mounted there
# inherits that ownership instead of being created root-owned.

FROM eclipse-temurin:17-jre

# curl is only for the health check; ca-certificates is already in the base image
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 10001 validator \
 && mkdir /home/validator/.fhir \
 && chown validator:validator /home/validator/.fhir

WORKDIR /app
COPY --chown=validator:validator validator_cli.jar /app/validator_cli.jar

USER validator
ENV FHIR_VERSION=5.0 \
    VALIDATOR_ARGS=""

EXPOSE 8080

# the server answers its OpenAPI document once the engine is loaded
HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=5 \
  CMD curl -fsS http://localhost:8080/openapi.json > /dev/null || exit 1

# -allowNetworkAccess: the server is reached from the other containers of the
# test bed, not from loopback. It has no authentication; do not expose the port
# beyond the compose network.
ENTRYPOINT ["/bin/sh", "-c", "exec java -jar /app/validator_cli.jar server 8080 -version \"$FHIR_VERSION\" -allowNetworkAccess $VALIDATOR_ARGS"]
