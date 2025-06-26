{ lib, config, pkgs, ... }:
let

  cfg = config.lab_paperless;
  name = "paperless";
  unitnames = ["paperless-scheduler.service" "paperless-task-queue.service" "paperless-web.service" ];
  secretfile = secrets/paperless.yaml;

in with lib; {
  options = {
    lab_paperless = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable paperles?
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

    services.paperless.enable = true;

    sops.secrets.paperless_dbpass = {
          sopsFile = secretfile;
          key = "dbpass";
          mode = "400";
          restartUnits = unitnames;
    };
    sops.secrets.paperless_dbhost = {
          sopsFile = secretfile;
          key = "dbhost";
          mode = "400";
          restartUnits = unitnames;
    };
    sops.secrets.paperless_socialaccount_providers = {
          sopsFile = secretfile;
          key = "socialaccount_providers";
          mode = "400";
          restartUnits = unitnames;
    };

    services.paperless.settings= {
        PAPERLESS_URL = "https://${name}.${config.homelab.domain}";
        PAPERLESS_PROXY_SSL_HEADER= ["HTTP_X_FORWARDED_PROTO" "https"];
        PAPERLESS_DBENGINE= "postgres";
        PAPERLESS_DBUSER= "paperless-ngx";
        PAPERLESS_DBNAME= "paperless-ngx";

    };
    services.paperless.environmentFile = config.sops.templates."paperless.env".path;
    sops.templates."paperless.env".owner = name;
    sops.templates."paperless.env".content = ''
PAPERLESS_DBPASS="${config.sops.placeholder.paperless_dbpass}"
PAPERLESS_DBHOST="${config.sops.placeholder.paperless_dbhost}"

PAPERLESS_SOCIALACCOUNT_PROVIDERS=${config.sops.placeholder.paperless_socialaccount_providers}


  '';
    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };

    services.traefik.dynamicConfigOptions.http.routers.paperless = mkIf cfg.expose_with_traefik {
        rule = "Host(`${name}.${config.homelab.domain}`)";
        service = "${name}@file";
    };
    services.traefik.dynamicConfigOptions.http.services.paperless = mkIf cfg.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:${ toString config.services.paperless.port}";

          }
        ];
      };
    };

    services.postgresql.ensureDatabases = [ "paperless-ngx" ];
    services.postgresql.ensureUsers = [{
      name = "paperless-ngx";
      ensureDBOwnership = true;
    }];

  };
}
