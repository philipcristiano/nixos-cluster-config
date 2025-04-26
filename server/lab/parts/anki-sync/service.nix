{ lib, config, pkgs, ... }:
let

in with lib; {
  options = {
    lab_anki_sync = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable anki-sync?
        '';
      };
      expose_with_traefik = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable exposing with traefik
        '';
      };
    };
  };
  config = mkIf config.lab_traefik.enable {
    environment.systemPackages = [
      pkgs.anki-sync-server
    ];

    sops.secrets.anki-sync-users-philipcristiano = {
          sopsFile = secrets/users.yaml;
          path = "/var/lib/anki-sync/users/philipcristiano";
          key = "philipcristiano";
          mode = "400";
          restartUnits = ["anki-sync-server.service"];
    };

    services.anki-sync-server.enable = true;
    services.anki-sync-server.users = [
        { username = "philipcristiano"; passwordFile = config.sops.secrets.anki-sync-users-philipcristiano.path; }
    ];

    services.traefik.dynamicConfigOptions.http.routers.anki_sync = mkIf config.lab_anki_sync.expose_with_traefik {
        rule = "Host(`anki-sync.${config.homelab.domain}`)";
        service = "anki_sync@file";
    };
    services.traefik.dynamicConfigOptions.http.services.anki_sync = mkIf config.lab_anki_sync.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://${config.services.anki-sync-server.address}:${toString config.services.anki-sync-server.port}";
          }
        ];
      };
    };
  };
}
