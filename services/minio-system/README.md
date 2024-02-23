


OIDC requires disabling PKCE on Kanidm for the resource server

```
kanidm system oauth2 warning-insecure-client-disable-pkce minio
```

Scope map should have roles required in Minio

```
kanidm system oauth2 update-scope-map minio <groupd name> openid profile email consoleAdmin
```
