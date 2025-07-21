
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_rotki;
  name = "rotki";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );


in with lib; {
  options = {
    lab_rotki = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable rotki?
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
  config = mkIf config.lab_rotki.enable {

    environment.systemPackages = [];

    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        rotki = {
            image = dockerImage;
            autoStart = true;
            ports = [ "127.0.0.1:4242:80" ];
            environment =  {
                ROTKI_ACCEPT_DOCKER_RISK = "1";
                TZ = "America/New_York";
                LOGLEVEL = "debug";
            };
            volumes = ["/var/lib/${name}:/data"];
        };
    };

    systemd.tmpfiles.rules = [
        "d /var/lib/${name} 0750 ${name} ${name} - "
    ];

    services.restic.backups.persist.paths = ["/var/lib/${name}/"];

    services.traefik.dynamicConfigOptions.http.routers.rotki = mkIf config.lab_rotki.expose_with_traefik {
        rule = "Host(`rotki.${config.homelab.domain}`)";
        service = "rotki@file";
    };
    services.traefik.dynamicConfigOptions.http.services.rotki = mkIf config.lab_rotki.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:4242";
          }
        ];
      };
    };
  };
}
