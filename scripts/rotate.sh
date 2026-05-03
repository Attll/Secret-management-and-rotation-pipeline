#!/bin/sh
set -e

export VAULT_ADDR=http://vault:8200

echo "[rotate.sh] Authenticating with Vault..."
VAULT_TOKEN=$(curl -s --request POST \
  --data "{\"role_id\":\"${ROLE_ID}\",\"secret_id\":\"${SECRET_ID}\"}" \
  $VAULT_ADDR/v1/auth/approle/login \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['auth']['client_token'])")

export VAULT_TOKEN

echo "[rotate.sh] Rotating PostgreSQL root credential..."
curl -s \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --request POST \
  $VAULT_ADDR/v1/database/rotate-root/postgres

echo "[rotate.sh] Root credential rotated successfully."
echo "[rotate.sh] Vault now manages the new root password — it is not known to any human."