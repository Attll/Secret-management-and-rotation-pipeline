#!/bin/sh
export VAULT_TOKEN=root
export VAULT_ADDR=http://127.0.0.1:8200

echo "=== Seeding Vault ==="

# KV engine (ignore error if already enabled)
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "KV already enabled, skipping"

vault kv put secret/app/db username='appuser' password='supersecret123'

vault policy write jenkins-policy - <<EOF
path "secret/data/app/*" {
  capabilities = ["read", "list"]
}
path "database/creds/app-role" {
  capabilities = ["read"]
}
EOF

# AppRole (ignore error if already enabled)
vault auth enable approle 2>/dev/null || echo "AppRole already enabled, skipping"

vault write auth/approle/role/jenkins \
  token_policies='jenkins-policy' \
  token_ttl=1h \
  token_max_ttl=4h

echo ""
echo "=== COPY THESE VALUES INTO JENKINS CREDENTIALS ==="
echo "ROLE_ID:"
vault read -field=role_id auth/approle/role/jenkins/role-id
echo "SECRET_ID:"
vault write -field=secret_id -f auth/approle/role/jenkins/secret-id