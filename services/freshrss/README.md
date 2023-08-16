

# OIDC

kanidm system oauth2 create freshrss "FreshRSS" <origin>
kanidm system oauth2 update-scope-map freshrss <group> openid
kanidm system oauth2 prefer-short-username freshrss
kanidm system oauth2 warning-insecure-client-disable-pkce freshrss
