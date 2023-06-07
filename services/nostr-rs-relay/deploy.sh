set -ex

vault policy write service-nostr-rs-relay policy.vault
vault write pki_int/roles/nostr-rs-relay \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="nostr-relay.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

# nomad volume create nostr-rs-relay-postgres.volume
nomad run nostr-rs-relay-postgres-backup.nomad
nomad run nostr-rs-relay-postgres.nomad
nomad run nostr-rs-relay.nomad
