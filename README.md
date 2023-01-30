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
