set -ex

vault policy write service-homeassistant policy.vault
vault write pki_int/roles/homeassistant \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="homeassistant.home.cristiano.cloud" \
     allow_bare_domains=true \
     allow_subdomains=true \
     max_ttl="720h"

# nomad volume create homeassistant.volume
# nomad volume create homeassistant-whisper.volume
# nomad volume create homeassistant-piper.volume
nomad run homeassistant.nomad
nomad run homeassistant-whisper.nomad
nomad run homeassistant-piper.nomad
