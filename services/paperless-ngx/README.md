
# Auth
kanidm system oauth2 create paperless-ngx PaperlessNGX https://…

kanidm system oauth2 update-scope-map paperless-ngx [GROUP] openid profile email

kanidm system oauth2 show-basic-secret paperless-ngx
# kanidm system oauth2 warning-enable-legacy-crypto paperless-ngx
