# Nix server setup

cp {*.lock,*.nix} to /etc/nixos/ on a server

```
sudo nixos-rebuild switch --flake /etc/nixos#server
```

```
scp {*.lock,*.nix} [SERVER]:/etc/nixos/
```

scp {*.lock,*.nix} philipcristiano@192.168.102.100:/etc/nixos/ && scp {*.lock,*.nix} philipcristiano@192.168.102.101:/etc/nixos/ && scp {*.lock,*.nix} philipcristiano@192.168.102.102:/etc/nixos/
