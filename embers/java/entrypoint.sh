#!/usr/bin/env bash
set -Eeuo pipefail

cd /server

: "${KILN_ARTIFACT_URL:?KILN_ARTIFACT_URL is required}"
: "${KILN_ARTIFACT_FILE:?KILN_ARTIFACT_FILE is required}"

if [[ ! -s "${KILN_ARTIFACT_FILE}" ]]; then
  temporary=".${KILN_ARTIFACT_FILE}.download"
  echo "[Kiln Ember] downloading ${KILN_IMPLEMENTATION:-server} ${KILN_VERSION:-unknown}"
  curl --fail --location --retry 3 --retry-all-errors \
    --connect-timeout 15 --max-time 300 \
    --output "${temporary}" "${KILN_ARTIFACT_URL}"
  mv -- "${temporary}" "${KILN_ARTIFACT_FILE}"
fi

if [[ -n "${KILN_ARTIFACT_SHA256:-}" ]]; then
  printf '%s  %s\n' "${KILN_ARTIFACT_SHA256}" "${KILN_ARTIFACT_FILE}" | sha256sum --check --status
fi

if [[ "${KILN_SERVER_KIND:-minecraft}" == "minecraft" ]]; then
  printf 'eula=true\n' > eula.txt
  if [[ ! -f server.properties ]]; then
    printf '%s\n' \
      'server-port=25565' \
      'online-mode=false' \
      'motd=Kiln managed server' \
      'enable-rcon=false' > server.properties
  fi
fi

read -r -a extra_java_args <<< "${KILN_JAVA_ARGS:-}"
read -r -a server_args <<< "${KILN_SERVER_ARGS:---nogui}"
java_memory_args=(-Xms"${MIN_RAM:-512M}")
if [[ -n "${MAX_RAM:-}" ]]; then
  java_memory_args+=(-Xmx"${MAX_RAM}")
else
  java_memory_args+=("-XX:MaxRAMPercentage=${KILN_JAVA_MAX_RAM_PERCENTAGE:-75.0}")
fi

echo "[Kiln Ember] starting ${KILN_IMPLEMENTATION:-server} ${KILN_VERSION:-unknown} with Java $(java -version 2>&1 | head -1)"
exec java \
  "${java_memory_args[@]}" \
  "${extra_java_args[@]}" \
  -jar "${KILN_ARTIFACT_FILE}" \
  "${server_args[@]}"
