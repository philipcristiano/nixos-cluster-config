{ lib, config, pkgs, ... }:
let

  cfg = config.lab_homeassistant;
  name = "homeassistant";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );

in with lib; {
  options = {
    lab_homeassistant = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable homeassistant?
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
  config = mkIf cfg.enable {

    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        homeassistant = {
            image = dockerImage;
            autoStart = true;
            ports = [ "127.0.0.1:8123:8123" ];
            networks = ["host"];
            volumes = ["/var/lib/${name}:/config"];
        };
    };

    systemd.tmpfiles.rules = [
        "d /var/lib/${name} 0750 ${name} ${name} - "
    ];

    services.restic.backups.persist.paths = ["/var/lib/${name}/backups"];

    services.traefik.dynamicConfigOptions.http.routers.homeassistant = mkIf cfg.expose_with_traefik {
        rule = "Host(`${name}.${config.homelab.domain}`)";
        service = "${name}@file";
    };
    services.traefik.dynamicConfigOptions.http.services.homeassistant = mkIf cfg.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:8123";
          }
        ];
      };
    };

  };
}
