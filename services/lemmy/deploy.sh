set -ex

vault policy write service-lemmy policy.vault
vault write pki_int/roles/lemmy \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="lemmy.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

# nomad volume create lemmy-postgres.volume
nomad run lemmy-postgres-backup.nomad
nomad run lemmy-postgres.nomad
nomad run -var count=2 lemmy.nomad
nomad run lemmy-ui.nomad
