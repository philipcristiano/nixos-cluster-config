
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_simplefin_rotki;
  name = "simplefin_rotki";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );


in with lib; {
  options = {
    lab_simplefin_rotki = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable simplefin_rotki?
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
  config = mkIf config.lab_simplefin_rotki.enable {

    environment.systemPackages = [];

    sops.templates."simplefin_rotki.toml".owner = name;
    sops.templates."simplefin_rotki.toml".content = ''

url = "https://simplefin-rotki.${config.homelab.domain}"

  '';
    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        simplefin-rotki = {
            image = dockerImage;
            autoStart = true;
            volumes =  ["${config.sops.templates."simplefin_rotki.toml".path}:/etc/simplefin_rotki.toml"];
            ports = [ "127.0.0.1:3033:3000" ];
            cmd = ["--bind-addr=0.0.0.0:3000"
                    "--config-file=/etc/simplefin_rotki.toml"
            ];
        };
    };


    services.traefik.dynamicConfigOptions.http.routers.simplefin_rotki = mkIf config.lab_simplefin_rotki.expose_with_traefik {
        rule = "Host(`simplefin-rotki.${config.homelab.domain}`)";
        service = "simplefin_rotki@file";
    };
    services.traefik.dynamicConfigOptions.http.services.simplefin_rotki = mkIf config.lab_simplefin_rotki.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:3033";
          }
        ];
      };
    };
  };
}
