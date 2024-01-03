

# OIDC

## Kanidm Tools
kanidm system oauth2 create directus Directus https://directus.home.cristiano.cloud

kanidm system oauth2 update-scope-map directus hazzard_members openid profile email

kanidm system oauth2 show-basic-secret directus
kanidm system oauth2 warning-enable-legacy-crypto directus

## Dependencies

* Minio bucket `directus`
* Postgres

## Vault Config

{
  "DEFAULT_ROLE_ID": "",
  "KEY": "",
  "SECRET": "",
  "OIDC_CLIENT_ID": "directus",
  "OIDC_CLIENT_SECRET": "",
  "S3_ACCESS_KEY": "",
  "S3_BUCKET": "directus",
  "S3_SECRET_KEY": ""
}
