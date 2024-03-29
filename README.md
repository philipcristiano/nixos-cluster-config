# nixos-cluster-config
Cluster of nixos nodes

On the host:

`touch /etc/nixos/ncluster.nix; chown philipcristiano /etc/nixos/ncluster.nix`

Then

`scp ncluster.nix $USER@TARGET_HOST:/etc/nixos/ncluster.nix`

Add `./ncluster.nix` to the imports

## Cluster bootstrapping

### Vault

See [vault/README.md](vault/README.md)

## Consul Value

Expected consul values

`site/domain` - Base domain expected for services.

## Networking

### VLANs

VLANs are used to provide separate interfaces for applications.
This is meant to work around limitations in macvlan interfaces in linux where the host cannot reach the macvlan'd interfaces.

In your nixos/configuration

```
  networking.vlans = {
	vlan110 = { id=110; interface="enp2s0"; };
  };
  networking.interfaces.vlan110.useDHCP = true;
```

### BGP

BGP is used with GoCast to advertise floating IPs


## Site configuration

### `nomad_job.vars`

`domain` Internal domain for services
`docker_registry` Custom registry to use, should be equal to `docker-registry.$DOMAIN` if you are using this docker registry

## Services

(WIP)
```
bash deploy.sh
```


### Storage

Minio for S3-compatible storage that can be hosted on each node.

NFS (hosted outside this cluster) is used for services that cannot use S3

### Database


Postgres deployed for each service.


### Reverse-Proxy

Traefik and Let's Encrypt for certs



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

### Baserow

#### Setup

Consul Values

* `credentials/baserow-postgres/USER` - Username for the root user
* `credentials/baserow-postgres/PASSWORD` - Root password
* `credentials/baserow-postgres/DB` - default DB
* `credentials/baserow-redis/password` - Username for the root user

## Bitcoin (and electrs, bitcoin-rpc-explorer, mempool)

NOT SAFE FOR USAGE AS A WALLET - only using this for an API to bitcoin data

Mempool also requires MariaDB



Consul Values

* `credentials/electrs/bitcoind_username` - Username from above
* `credentials/electrs/bitcoind_password` - Password generated by rpcauth

* `credentials/bitcoin-rpc-explorer/bitcoind_username` - Username from above
* `credentials/bitcoin-rpc-explorer/bitcoind_password` - Password generated by rpcauth

* `credentials/mempool/bitcoind_username` - Username from above
* `credentials/mempool/bitcoind_password` - Password generated by rpcauth

For each service:
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

### Matrix

#### Matrix-Hookshot

* `credentials/matrix-hookshot/passkey.pem` - passkey.pem from `openssl genpkey -out passkey.pem -outform PEM -algorithm RSA -pkeyopt rsa_keygen_bits:4096`

# Nomad Admin

### Set spread scheduling algorithm

```
curl -s $NOMAD_ADDR/v1/operator/scheduler/configuration |
    jq '.SchedulerConfig | .SchedulerAlgorithm="spread"' |
  curl -X PUT $NOMAD_ADDR/v1/operator/scheduler/configuration -d @-
```

### Allow memory oversubscription

```
curl -s $NOMAD_ADDR/v1/operator/scheduler/configuration | \
  jq '.SchedulerConfig | .MemoryOversubscriptionEnabled=true' | \
  curl -X PUT $NOMAD_ADDR/v1/operator/scheduler/configuration -d @-
```
