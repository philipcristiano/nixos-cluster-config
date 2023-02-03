# nixos-cluster-config
Cluster of nixos nodes

On the host:

`touch /etc/nixos/ncluster.nix; chown philipcristiano /etc/nixos/ncluster.nix`

Then

`scp ncluster.nix philipcristiano@TARGET_HOST:/etc/nixos/ncluster.nix`

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
