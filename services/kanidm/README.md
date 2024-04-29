# Add OIDC resource server


kanidm system oauth2 create <name> <displayname> <origin>
kanidm system oauth2 create nextcloud "Nextcloud Production" https://nextcloud.example.com

kanidm system oauth2 update-scope-map <name> <kanidm_group_name> [scopes]...
kanidm system oauth2 update-scope-map nextcloud nextcloud_admins openid profile email

Get resource server secret with

kanidm system oauth2 show-basic-secret <name>

## POTENTIALLY

kanidm system oauth2 warning-insecure-client-disable-pkce <resource server name>

# RADIUS

```
kanidm service-account create --name admin radius_service_account "Radius Service Account"
kanidm group add-members --name admin idm_radius_servers radius_service_account
kanidm service-account credential generate --name admin radius_service_account
```


TODO: Update add_members doc for radius
