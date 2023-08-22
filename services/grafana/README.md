

# OIDC

kanidm system oauth2 create grafana Grafana <origin>

kanidm system oauth2 update-scope-map grafana <group> openid profile email scopes


## Set roles
Add additional scopes for Viewer Editor or Admin roles

kanidm system oauth2 update-sup-scope-map grafana <editor_group> editor

## Add secret to vault `kv/grafana`
kanidm system oauth2 show-basic-secret <name>


