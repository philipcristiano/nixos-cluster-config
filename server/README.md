# Nix server setup

cp {*.lock,*.nix} to /etc/nixos/ on a server

```
sudo nix-channel --add https://channels.nixos.org/nixos-24.05 nixos
sudo nixos-rebuild switch --flake /etc/nixos
```

```
deploy --remote-build --skip-checks
```



## Adding a disk

```
nix-shell -p parted

parted /dev/sda -- mklabel gpt
parted -a optimal /dev/sda mkpart primary 0% 100%
mkfs.ext4 -L data /dev/sda1

```

Edit `/etc/nixos/hardware-configuration.nix` and add:

```
 fileSystems."/mnt/data" =
    { device = "/dev/disk/by-label/data";
      fsType = "ext4";
    };
```
