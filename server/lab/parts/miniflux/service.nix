{ lib, config, pkgs, ... }:
let

  cfg = config.lab_miniflux;
  name = "miniflux";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );

in with lib; {
  options = {
    lab_miniflux = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable miniflux?
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

    sops.secrets.miniflux-databaseurl-secret = {
          sopsFile = secrets/${name}.yaml;
          key = "database_url";
          mode = "400";
          restartUnits = [ "docker-miniflux.service"];
    };
    sops.secrets.miniflux-client-id = {
          sopsFile = secrets/${name}.yaml;
          key = "oidc_client_id";
          mode = "400";
          restartUnits = [ "docker-miniflux.service"];
    };
    sops.secrets.miniflux-client-secret = {
          sopsFile = secrets/${name}.yaml;
          key = "oidc_client_secret";
          mode = "400";
          restartUnits = [ "docker-miniflux.service"];
    };
    sops.templates."${name}.env".content = ''

DATABASE_URL=${config.sops.placeholder.miniflux-databaseurl-secret}
PORT=8095

OAUTH2_PROVIDER=oidc
OAUTH2_CLIENT_ID=${config.sops.placeholder.miniflux-client-id}
OAUTH2_CLIENT_SECRET=${config.sops.placeholder.miniflux-client-secret}
OAUTH2_REDIRECT_URL=https://${name}.${config.homelab.domain}/oauth2/oidc/callback
OAUTH2_OIDC_DISCOVERY_ENDPOINT=https://kanidm.${config.homelab.domain}/oauth2/openid/${config.sops.placeholder.miniflux-client-id}
OAUTH2_USER_CREATION=1

RUN_MIGRATIONS=1
LOG_FILE=stdout
LOG_FORMAT=json
METRICS_COLLECTOR=1
METRICS_ALLOWED_NETWORKS="10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,127.0.0.1/32"

LOG_LEVEL=debug
LOG_DATE_TIME=1

# Don't automatically disable feeds for parse errors
POLLING_PARSING_ERROR_LIMIT=0

POLLING_FREQUENCY=15
POLLING_SCHEDULER=entry_frequency

HTTP=1

  '';
    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        miniflux = {
            image = dockerImage;
            autoStart = true;
            #ports = [ "127.0.0.1:3002:3000" ];
            volumes =  ["${config.sops.templates."miniflux.env".path}:/etc/miniflux.env"];
            networks = ["host"];
            environmentFiles = [config.sops.templates."miniflux.env".path];
        };
    };

    services.traefik.dynamicConfigOptions.http.routers.miniflux = mkIf cfg.expose_with_traefik {
        rule = "Host(`${name}.${config.homelab.domain}`)";
        service = "${name}@file";
    };
    services.traefik.dynamicConfigOptions.http.services.miniflux = mkIf cfg.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:8095";
          }
        ];
      };
    };

    services.postgresql.ensureDatabases = [ name ];
    services.postgresql.ensureUsers = [{
      name = name;
      ensureDBOwnership = true;
    }];

  };
}
