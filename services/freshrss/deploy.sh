set -ex

vault policy write service-freshrss policy.vault
vault write pki_int/roles/freshrss \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="freshrss.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

# nomad volume create freshrss.volume
nomad run -var-file=../../nomad_job.vars freshrss.nomad
