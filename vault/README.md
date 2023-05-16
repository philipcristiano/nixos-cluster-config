
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
mkdir -p /var/lib/vault/certs
sudo chown $USER /var/lib/vault/certs
```

Copy into place

```
scp ca-cert.pem vault-key.pem vault-cert.pem vault-0.$DOMAIN:/var/lib/vault/certs
scp ca-cert.pem vault-key.pem vault-cert.pem vault-1.$DOMAIN:/var/lib/vault/certs
scp ca-cert.pem vault-key.pem vault-cert.pem vault-2.$DOMAIN:/var/lib/vault/certs
```

Setup permissions for vault

```

sudo chmod 755 /var/lib/vault/certs/ca-cert.pem

```

Set your shell for things


```
export VAULT_CACERT=/var/lib/vault/certs/ca-cert.pem


```
export VAULT_ADDR=https://vault-0.$DOMAIN:8200
export VAULT_SKIP_VERIFY=true
vault operator init -tls-skip-verify

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

