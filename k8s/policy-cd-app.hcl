path "secret/*" {
  capabilities = ["list", "read"]
}
path "auth/approle/role/cd-app/secret-id" {
  capabilities = ["update"]
}
