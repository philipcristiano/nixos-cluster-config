set -ex

vault policy write service-calibre-web policy.vault
vault write pki_int/roles/calibre-web \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="calibre.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

# nomad volume create ccsi-nfs-calibre-web.volume
nomad run calibre-web.nomad
