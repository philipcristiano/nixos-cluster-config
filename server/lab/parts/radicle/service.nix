
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_radicle;
  name = "radicle";


in with lib; {
  options = {
    lab_radicle = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable radicle?
        '';
      };
      enable_http = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable radicle http interface?
        '';
      };
      expose_http_with_traefik = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable exposing with traefik
        '';
      };
    };
  };
  config = mkIf config.lab_radicle.enable {
    sops.secrets.radicle_private_key = {
          sopsFile = secrets/radicle.yaml;
          key = "private_key";
          mode = "400";
          restartUnits = ["radicle-node.service"];
          owner = name;
    };
    sops.secrets.radicle_public_key = {
          sopsFile = secrets/radicle.yaml;
          key = "public_key";
          mode = "400";
          restartUnits = ["radicle-node.service"];
          owner = name;
    };

    services.radicle = {
        enable = true;
        privateKeyFile = config.sops.secrets.radicle_private_key.path;
        publicKey = config.sops.secrets.radicle_public_key.path;
        node.openFirewall = true;
        node.listenAddress = "0.0.0.0";
        node.listenPort = 8776;

        httpd.enable = config.lab_radicle.enable_http;
    };

    services.radicle.settings = {
        node.alias = "test-node";
        seedingPolicy.default = "block";
    };

    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };


    services.traefik.dynamicConfigOptions.http.routers.${name} = mkIf config.lab_radicle.expose_http_with_traefik {
        rule = "Host(`radicle.${config.homelab.domain}`)";
        service = "radicle@file";
    };
    services.traefik.dynamicConfigOptions.http.services.${name} = mkIf config.lab_radicle.expose_http_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:${toString config.services.radicle.httpd.listenPort}";
          }
        ];
      };
    };
  };
}
