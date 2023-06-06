set -ex

vault policy write service-synapse policy.vault
vault write pki_int/roles/synapse \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="synapse.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

# nomad volume create synapse-postgres.volume
# nomad volume create synapse.volume
nomad run synapse-postgres-backup.nomad
nomad run synapse-postgres.nomad
nomad run synapse.nomad