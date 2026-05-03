# jenkins-policy.hcl
# This policy defines exactly what Jenkins is allowed to do in Vault.
# It cannot write, delete, or access any other path.

path "secret/data/app/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/app/*" {
  capabilities = ["list"]
}

path "database/creds/app-role" {
  capabilities = ["read"]        # for Phase 5 — dynamic DB credentials
}