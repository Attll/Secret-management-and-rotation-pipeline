export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

echo "Enabling KV v2 secrets engine..."
vault secrets enable -path=secret kv-v2

echo "Storing initial secrets..."
vault kv put secret/app/db \
  username="appuser" \
  password="initialpassword123"

echo "Writing Jenkins policy..."
vault policy write jenkins-policy - <<EOF
path "secret/data/app/*" {
  capabilities = ["read", "list"]
}
path "database/creds/app-role" {
  capabilities = ["read"]
}
EOF

echo "Enabling AppRole auth..."
vault auth enable approle

echo "Creating Jenkins role..."
vault write auth/approle/role/jenkins \
  token_policies="jenkins-policy" \
  token_ttl=1h \
  token_max_ttl=4h

echo "Role ID:"
vault read -field=role_id auth/approle/role/jenkins/role-id

echo "Secret ID:"
vault write -field=secret_id -f auth/approle/role/jenkins/secret-id

echo "Done. Save the Role ID and Secret ID above."