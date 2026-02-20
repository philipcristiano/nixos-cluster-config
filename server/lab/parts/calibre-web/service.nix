{ lib, config, pkgs, ... }:
let

  cfg = config.lab_calibre_web;
  name = "calibre-web";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );
  dockerFileMetadata = builtins.readFile ./Dockerfile.metadata;
  dockerImageMetadata = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFileMetadata );
  local_port = 8083;
  metadata_local_port = 8084;

in with lib; {
  options = {
    lab_calibre_web = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable calibre web?
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
    systemd.tmpfiles.rules = [
        "d /var/lib/${name} 0750 ${name} ${name} - "
    ];

    sops.templates."calibre-metadata-api.toml".restartUnits = ["docker-calibre-metadata-api.service"];
    sops.templates."calibre-metadata-api.toml".owner = name;
    sops.templates."calibre-metadata-api.toml".content = ''

database_url = "/config/books/metadata.db"
'';
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        calibre-web = {
            image = dockerImage;
            autoStart = true;
            volumes = ["/var/lib/${name}:/config"];
            ports = [ "127.0.0.1:${toString local_port}:8083" ];
            environment = {
              OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://tempo-otlp-grpc.${config.homelab.domain}:443";
              OTEL_EXPORTER_OTLP_PROTOCOL="grpc";
              OTEL_SERVICE_NAME="et";
            };
        };
        calibre-metadata-api = {
            image = dockerImageMetadata;
            autoStart = true;
            volumes = ["/var/lib/${name}:/config"
                      "${config.sops.templates."calibre-metadata-api.toml".path}:/config.toml"];
            ports = [ "127.0.0.1:${toString metadata_local_port}:3002"];
            cmd =  [
                "--bind-addr" "0.0.0.0:3002"
                "--config-file" "/config.toml"
                 "--log-level" "DEBUG"
            ];
            environment = {
              OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://tempo-otlp-grpc.${config.homelab.domain}:443";
              OTEL_EXPORTER_OTLP_PROTOCOL="grpc";
              OTEL_SERVICE_NAME="et";
            };
        };
    };
    services.restic.backups.persist.paths = ["/var/lib/${name}"];

    services.traefik.dynamicConfigOptions.http.routers.calibre-web = mkIf cfg.expose_with_traefik {
        rule = "Host(`calibre.${config.homelab.domain}`)";
        service = "${name}@file";
    };
    services.traefik.dynamicConfigOptions.http.services.calibre-web = mkIf cfg.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:${toString local_port}";
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
