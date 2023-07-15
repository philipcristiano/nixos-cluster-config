set -ex

vault policy write service-syslog-ng policy.vault
vault write pki_int/roles/syslog-ng \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="syslog.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

nomad run -var=count=1 syslog-ng.nomad
