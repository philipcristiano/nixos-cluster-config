
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_woodpecker;
  name = "woodpecker";
  listenPort = "3007";

in with lib; {
  options = {
    lab_woodpecker = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable woodpecker?
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
  config = mkIf config.lab_woodpecker.enable {
    sops.secrets.woodpecker_agent_secret = {
          sopsFile = secrets/woodpecker.yaml;
          key = "agent_secret";
          mode = "400";
          restartUnits = ["woodpecker-node.service"];
          owner = name;
    };

    services.woodpecker-server = {
        enable = true;
        environmentFile = [
          config.sops.templates."woodpecker.env".path
        ];
        environment = {
          WOODPECKER_HOST = "https://${name}.${config.homelab.domain}";
          WOODPECKER_SERVER_ADDR = ":${toString listenPort}";
          WOODPECKER_OPEN = "true";
        };
    };

    sops.templates."woodpecker.env".owner = name;

    sops.templates."woodpecker.env".content = ''

WOODPECKER_AGENT_SECRET=config.sops.placeholder.woodpecker_agent_secret
'';

    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };


    services.traefik.dynamicConfigOptions.http.routers.${name} = mkIf config.lab_woodpecker.expose_with_traefik {
        rule = "Host(`woodpecker.${config.homelab.domain}`)";
        service = "woodpecker@file";
    };
    services.traefik.dynamicConfigOptions.http.services.${name} = mkIf config.lab_woodpecker.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:${toString listenPort}";
          }
        ];
      };
    };
  };
}
