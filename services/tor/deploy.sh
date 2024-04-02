set -ex

vault policy write service-tor policy.vault
vault write pki_int/roles/tor \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="tor.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

nomad run tor.nomad
