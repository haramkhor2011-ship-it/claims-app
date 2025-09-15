#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/claims}"
CONFIG_DIR="$APP_DIR/config"
MODE="${AME_MODE:-PKCS12}"                # PKCS12|FILE
KS_ALIAS="${AME_ALIAS:-claims-ame}"
KS_PASS="${AME_PASS:-Str0ngP@ssw0rd}"     # only used for PKCS12
KEYID="${AME_KEYID:-claims-ame.v1}"

ADMIN_URL="${ADMIN_URL:-http://localhost:8080}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"            # REQUIRED (SUPER_ADMIN Bearer token)
FAC_FILE="${FAC_FILE:-$APP_DIR/facilities.json}"  # facilities to seed

echo "== Claims AME post-install starting =="
echo "APP_DIR=$APP_DIR MODE=$MODE KEYID=$KEYID"

mkdir -p "$CONFIG_DIR"

if [[ "$MODE" == "PKCS12" ]]; then
  KS_PATH="$CONFIG_DIR/claims.p12"
  if [[ ! -f "$KS_PATH" ]]; then
    echo "-> Generating PKCS12 keystore at $KS_PATH"
    keytool -genseckey \
      -alias "$KS_ALIAS" \
      -keyalg AES -keysize 256 \
      -storetype PKCS12 \
      -keystore "$KS_PATH" \
      -storepass "$KS_PASS"
  else
    echo "-> Keystore already present at $KS_PATH"
  fi
  echo "-> Exporting CLAIMS_AME_STORE_PASS for systemd drop-in"
  mkdir -p /etc/systemd/system/claims.service.d
  cat >/etc/systemd/system/claims.service.d/10-ame-env.conf <<EOF
[Service]
Environment=CLAIMS_AME_STORE_PASS=$KS_PASS
EOF
elif [[ "$MODE" == "FILE" ]]; then
  KEY_PATH="$CONFIG_DIR/ame.key"
  if [[ ! -f "$KEY_PATH" ]]; then
    echo "-> Generating 32-byte key at $KEY_PATH"
    openssl rand -out "$KEY_PATH" 32
    chmod 600 "$KEY_PATH"
  else
    echo "-> Key file already present at $KEY_PATH"
  fi
else
  echo "ERROR: AME_MODE must be PKCS12 or FILE"
  exit 1
fi

# Patch application.yml if needed (only prints instructions here; your yml already supports AME)
echo "== Verify application.yml has:"
if [[ "$MODE" == "PKCS12" ]]; then
  echo "claims.security.ame.enabled=true"
  echo "claims.security.ame.keystore.type=PKCS12"
  echo "claims.security.ame.keystore.path=file:config/claims.p12"
  echo "claims.security.ame.keystore.alias=$KS_ALIAS"
  echo "claims.security.ame.crypto.keyId=$KEYID"
else
  echo "claims.security.ame.enabled=true"
  echo "claims.security.ame.keystore.type=FILE"
  echo "claims.security.ame.keystore.path=file:config/ame.key"
  echo "claims.security.ame.crypto.keyId=$KEYID"
fi

systemctl daemon-reload || true

# Optionally start/restart the app
if systemctl list-units | grep -q '^claims\.service'; then
  echo "-> Restarting claims.service"
  systemctl restart claims.service
  sleep 3
  echo "-> Tail last 50 lines:"
  journalctl -u claims -n 50 --no-pager || true
fi

# Seed facilities
if [[ -z "$ADMIN_TOKEN" ]]; then
  echo "SKIP seeding facilities: ADMIN_TOKEN not set"
  exit 0
fi
if [[ ! -f "$FAC_FILE" ]]; then
  cat > "$FAC_FILE" <<'JSON'
[
  {
    "facilityCode": "HOSP1",
    "facilityName": "City Hospital",
    "active": true,
    "endpointUrl": "https://qa.eclaimlink.ae/dhpo/ValidateTransactions.asmx",
    "soap12": false,
    "callerLicense": "LIC123",
    "ePartner": "EPART001",
    "login": "dhpo_user_hosp1",
    "password": "S3cureP@ss!"
  }
]
JSON
  echo "-> Created sample $FAC_FILE. Edit it and re-run to seed."
  exit 0
fi

echo "-> Seeding facilities from $FAC_FILE"
len=$(jq 'length' "$FAC_FILE")
for i in $(seq 0 $((len-1))); do
  body=$(jq -c ".[$i]" "$FAC_FILE")
  code=$(echo "$body" | jq -r '.facilityCode')
  echo "   - upserting facility $code"
  http_code=$(curl -s -o /tmp/fac.out -w "%{http_code}" \
    -X POST "$ADMIN_URL/admin/facilities" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d "$body")
  if [[ "$http_code" != "200" && "$http_code" != "204" ]]; then
    echo "     ERROR ($http_code): $(cat /tmp/fac.out)"
    exit 1
  fi
done

echo "== Post-install completed successfully =="
