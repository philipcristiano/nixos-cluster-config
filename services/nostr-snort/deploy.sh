set -ex

vault policy write service-nostr-snort policy.vault
vault write pki_int/roles/nostr-snort \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="snort.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

nomad run nostr-snort.nomad
