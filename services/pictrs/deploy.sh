set -ex

vault policy write service-pictrs policy.vault
vault write pki_int/roles/pictrs \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="pictrs.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

# nomad volume create pictrs.volume
nomad run pictrs.nomad
