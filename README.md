# nixos-cluster-config
Cluster of nixos nodes

On the host:

`touch /etc/nixos/ncluster.nix; chown philipcristiano /etc/nixos/ncluster.nix`

Then

`scp ncluster.nix philipcristiano@TARGET_HOST:/etc/nixos/ncluster.nix`
