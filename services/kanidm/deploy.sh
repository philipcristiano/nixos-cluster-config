set -ex

vault policy write service-kanidm policy.vault
vault write pki_int/roles/kanidm \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="kanidm.home.cristiano.cloud,ldap.home.cristiano.cloud,radius.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

# nomad volume create kanidm.volume
nomad run -var-file=../../nomad_job.vars -var-file=./service.vars kanidm.nomad
nomad run -var-file=../../nomad_job.vars -var-file=./service.vars kanidm-radius.nomad
nomad run -var-file=../../nomad_job.vars -var-file=./service.vars kanidm-tools.nomad
