#!/bin/bash
set -e

echo "========================================"
echo "AME KEYSTORE GENERATION"
echo "========================================"

KEYSTORE_DIR="./config"
KEYSTORE_FILE="$KEYSTORE_DIR/claims.p12"
ALIAS="claims-ame"
PASSWORD="${CLAIMS_AME_STORE_PASS:-DefaultPassword123}"

# Create config directory if it doesn't exist
mkdir -p "$KEYSTORE_DIR"

# Check if keystore already exists
if [ -f "$KEYSTORE_FILE" ]; then
  echo "Keystore already exists at $KEYSTORE_FILE"
  read -p "Regenerate? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Keystore generation cancelled."
    exit 0
  fi
  rm "$KEYSTORE_FILE"
  echo "Removed existing keystore."
fi

echo "Generating PKCS12 keystore for AME encryption..."
echo "Keystore location: $KEYSTORE_FILE"
echo "Alias: $ALIAS"
echo "Algorithm: AES-256"

# Generate the keystore
keytool -genseckey \
  -alias "$ALIAS" \
  -keyalg AES \
  -keysize 256 \
  -storetype PKCS12 \
  -keystore "$KEYSTORE_FILE" \
  -storepass "$PASSWORD"

# Set secure permissions
chmod 600 "$KEYSTORE_FILE"

echo "========================================"
echo "KEYSTORE GENERATION COMPLETE"
echo "========================================"
echo "Keystore generated successfully at: $KEYSTORE_FILE"
echo "Alias: $ALIAS"
echo "Password: $PASSWORD"
echo ""
echo "IMPORTANT: Add this to your .env file:"
echo "CLAIMS_AME_STORE_PASS=$PASSWORD"
echo ""
echo "Security notes:"
echo "- Keystore file has 600 permissions (owner read/write only)"
echo "- Change the password in production"
echo "- Keep the keystore file secure"
echo "========================================"
