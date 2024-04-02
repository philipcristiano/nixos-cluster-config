
#### Generate certs

```
# Root CA
openssl genrsa -out ca_key.pem 4096

# Root CSR
openssl req -x509 -sha256 -new -nodes -key ca_key.pem -days 10000 -out ca-cert.pem

# Server
openssl genrsa -out vault-key.pem 4096

# Server CSR
openssl req -new -key vault-key.pem -sha256 -out vault.csr -config cert.config

# Server Certs
openssl x509 -req -sha256 -in vault.csr -CA ca-cert.pem -CAkey ca_key.pem -CAcreateserial -out vault-cert.pem -days 10000 -extfile cert.config -extensions 'v3_req'
```

# Copy to servers

SSH to each and setup permissions for copying

```
sudo chmod 755 /var/lib/vault
sudo mkdir -p /var/lib/vault/{certs,ca}
sudo chown -R $USER:vault /var/lib/vault/{certs,ca}
```

Copy into place

```
scp vault-key.pem vault-cert.pem vault-0.$DOMAIN:/var/lib/vault/certs/
scp ca-cert.pem vault-0.$DOMAIN:/var/lib/vault/ca/

scp vault-key.pem vault-cert.pem vault-1.$DOMAIN:/var/lib/vault/certs/
scp ca-cert.pem vault-1.$DOMAIN:/var/lib/vault/ca/

scp vault-key.pem vault-cert.pem vault-2.$DOMAIN:/var/lib/vault/certs/
scp ca-cert.pem vault-1.$DOMAIN:/var/lib/vault/ca/
```

Setup permissions for vault

```

sudo chmod -R 755 /var/lib/vault/ca

```

Set your shell for things


```
export VAULT_CACERT=/var/lib/vault/ca/ca-cert.pem


```
export VAULT_ADDR=https://vault-0.home.cristiano.cloud:8200
vault operator init

vault  operator  unseal [UNSEAL 1]

export VAULT_ADDR=https://vault-1.$DOMAIN:8200
export VAULT_SKIP_VERIFY=true
vault operator raft join http://vault-0.$DOMAIN:8200

export VAULT_ADDR=https://vault-2.$DOMAIN:8200
export VAULT_SKIP_VERIFY=true
vault operator raft join http://vault-0.$DOMAIN:8200
```

# [Setup Nomad Vault Policies](https://developer.hashicorp.com/nomad/docs/integrations/vault-integration#vault-configuration)

```
# Download the policy
$ curl https://nomadproject.io/data/vault/nomad-server-policy.hcl -O -s -L

# Write the policy to Vault
$ vault policy write nomad-server nomad-server-policy.hcl
```

## Token Role

```
# Download the token role
$ curl https://nomadproject.io/data/vault/nomad-cluster-role.json -O -s -L

# Create the token role with Vault
$ vault write /auth/token/roles/nomad-cluster @nomad-cluster-role.json
```


Write a file on each server

/
```


# Vault PKI

```
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki

vault write -field=certificate pki/root/generate/internal \
     common_name="example.com" \
     issuer_name="root-2023" \
     ttl=87600h > root_2023_ca.crt

vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int

vault write -format=json pki_int/intermediate/generate/internal \
     common_name="Intermediate Authority" \
     issuer_name="intermediate" \
     | jq -r '.data.csr' > pki_intermediate.csr

vault write -format=json pki/root/sign-intermediate \
     issuer_ref="root-2023" \
     csr=@pki_intermediate.csr \
     format=pem_bundle ttl="43800h" \
     | jq -r '.data.certificate' > intermediate.cert.pem

vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem

```

### OIDC policies

```
vault policy write manager role-manager.vault

vault write auth/oidc/role/reader \
        bound_audiences="vault" \
        allowed_redirect_uris="https://vault.$DOMAIN/ui/vault/auth/oidc/oidc/callback" \
        allowed_redirect_uris="https://vault.$DOMAIN/oidc/callback" \
        user_claim="sub" \
        token_policies="reader"

vault write auth/oidc/role/manager \
        bound_audiences="vault" \
        allowed_redirect_uris="https://vault.$DOMAIN/ui/vault/auth/oidc/oidc/callback" \
        allowed_redirect_uris="https://vault.$DOMAIN/oidc/callback" \
        user_claim="sub" \
        token_policies="manager"
```


