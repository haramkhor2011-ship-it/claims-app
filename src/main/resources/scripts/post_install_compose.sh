#!/usr/bin/env bash
set -euo pipefail

# assumes docker-compose.yml mounts ./config into container at /workspace/config
MODE="${AME_MODE:-PKCS12}"  # PKCS12|FILE
KS_PASS="${AME_PASS:-Str0ngP@ssw0rd}"

mkdir -p config

if [[ "$MODE" == "PKCS12" ]]; then
  if [[ ! -f config/claims.p12 ]]; then
    echo "-> Generating PKCS12 keystore ./config/claims.p12"
    keytool -genseckey -alias claims-ame -keyalg AES -keysize 256 -storetype PKCS12 \
      -keystore config/claims.p12 -storepass "$KS_PASS"
  else
    echo "-> Keystore exists"
  fi
  echo "Set env in compose: CLAIMS_AME_STORE_PASS=$KS_PASS"
else
  if [[ ! -f config/ame.key ]]; then
    echo "-> Generating 32-byte key ./config/ame.key"
    openssl rand -out config/ame.key 32
    chmod 600 config/ame.key
  else
    echo "-> Key file exists"
  fi
fi

echo "Now: docker compose up -d"
