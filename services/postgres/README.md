
# Postgres

This service is meant to be reusable to deploy a Postgres instance for each application service that requires PG.

## Architecture

The Postgres Job runs with the per-container filesystem. On initialization the container will attempt to restore a backup and if successful, will enable the Consul service.

A backup task runs periodically to create the backup and store in Minio.

This removes the need for mapped-in remote storage (NFS and PG don't work well together) while trying to keep the whole setup simple.

## Deploying

Create a secret in Vault `kv/[NAME]-postgres`
```
{
  "DB": "[NAME]",
  "PASSWORD": "[PASSWORD]",
  "USER": "[NAME]"
  "DB_INIT": true
}
```

`bash deploy.sh [NAME]`

Trigger the first backup

`nomad job periodic force [NAME]-postgres-backup`

Remove `DB_INIT` from the secret

The database will restart, with the initialized database


### `DB_INIT`

The `DB_INIT` config will allow the initial restore operation to fail. Removing this will cause a restore failure to withhold enabling the Consul service, protecting against any restore failures from loading an empty database
