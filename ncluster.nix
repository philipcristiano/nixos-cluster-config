{ config, pkgs, ... }:

{ environment.systemPackages = [ pkgs.consul
                                 pkgs.nomad
                                 pkgs.vault];
  # services.consul.enable = true;
  # systemd.services.consul.serviceConfig.Type = "notify";

  services.nomad = {
    enableDocker = true;
    settings = {
        server = {
            enabled = true;
            bootstrap_expect = 3;
            server_join = {
                retry_join     = [ "192.168.102.100" "192.168.102.101" "192.168.102.102" ];
                retry_max      = 3;
                retry_interval = "15s";
            };
        };
        client = {
            enabled = true;
        };
    };
  };
  services.nomad.enable = true;
  networking.firewall.allowedTCPPortRanges = [
    { from = 4646; to = 4648; }
];
}
