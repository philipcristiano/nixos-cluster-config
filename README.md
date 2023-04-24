# nixos-cluster-config
Cluster of nixos nodes

On the host:

`touch /etc/nixos/ncluster.nix; chown philipcristiano /etc/nixos/ncluster.nix`

Then

`scp ncluster.nix $USER@TARGET_HOST:/etc/nixos/ncluster.nix`

Add `./ncluster.nix` to the imports

## Consul Value

Expected consul values

`site/domain` - Base domain expected for services.


## Jobs


### InfluxDB

#### Setup

Create bucket:

`host`

###  Telegraf

#### Setup
Create a token in InfluxDB and add to Consul

`credentials/telegraf-system/influxdb_token`

Set:

`credentials/telegraf-system/organization` to match the InfluxDB org

### mktxp / mikrotik monitoring

####

Consul values:

* `credentials/mktxp/influxdb_organization`
* `credentials/mktxp/influxdb_token`
* `credentials/mktxp/password`
* `credentials/mktxp/username`

### Minio / S3-compatible blog storage

Consul values:

* `credentials/minio/root_user`
* `credentials/minio/root_pass`

## Bitcoin (and electrs, bitcoin-rpc-explorer)

NOT SAFE FOR USAGE AS A WALLET - only using this for an API to bitcoin data

### Auth

Generate credentials with

`curl 'https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py' | python3 /dev/stdin [USERNAME]`



Consul Values

* `credentials/electrs/bitcoind_username` - Username from above
* `credentials/electrs/bitcoind_password` - Password generated by rpcauth

* `credentials/bitcoin-rpc-explorer/bitcoind_username` - Username from above
* `credentials/bitcoin-rpc-explorer/bitcoind_password` - Password generated by rpcauth

* `credentials/bitcoind/rpcauth/USERNAME` - RPC auth line after `rpcauth=USERNAME:` Just the salt/password portion!


## Folio

### Postgres

Consul Values

* `credentials/folio-postgres/USER` - Username for the root user
* `credentials/folio-postgres/PASSWORD` - Root password
* `credentials/folio-postgres/DB` - default DB


### Frigate

#### Setup


Consul Values

* `credentials/frigate/mqtt_host` - MQTT Host IP
* `credentials/frigate/mqtt_username` - MQTT Username
* `credentials/frigate/mqtt_password` - MQTT Password
* `credentials/frigate/cameras/*` - Key: Camera name, Value: input.path for Frigate
