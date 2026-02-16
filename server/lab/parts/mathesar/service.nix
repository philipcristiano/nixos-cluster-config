{ lib, config, pkgs, ... }:
let

  cfg = config.lab_mathesar;
  name = "mathesar";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );
  local_port = 8000;

in with lib; {
  options = {
    lab_mathesar = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable mathesar?
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

    sops.secrets.mathesar-postgres-user = {
          sopsFile = secrets/mathesar.yaml;
          key = "POSTGRES_USER";
          mode = "400";
          restartUnits = ["docker-mathesar.service"];
    };

    sops.secrets.mathesar-postgres-password = {
          sopsFile = secrets/mathesar.yaml;
          key = "POSTGRES_PASSWORD";
          mode = "400";
          restartUnits = ["docker-mathesar.service"];
    };

    sops.secrets.mathesar-postgres-host = {
          sopsFile = secrets/mathesar.yaml;
          key = "POSTGRES_HOST";
          mode = "400";
          restartUnits = ["docker-mathesar.service"];
    };

    sops.secrets.mathesar-postgres-port = {
          sopsFile = secrets/mathesar.yaml;
          key = "POSTGRES_PORT";
          mode = "400";
          restartUnits = ["docker-mathesar.service"];
    };

    sops.secrets.mathesar-secret-key = {
          sopsFile = secrets/mathesar.yaml;
          key = "SECRET_KEY";
          mode = "400";
          restartUnits = ["docker-mathesar.service"];
    };
    sops.templates."mathesar.env".owner = name;
    sops.templates."mathesar.env".restartUnits = ["docker-mathesar.service"];
    sops.templates."mathesar.env".content = ''
PORT=${toString local_port}
DJANGO_PORT=${toString local_port}
DOMAIN_NAME=https://mathesar.${config.homelab.domain}
ALLOWED_HOSTS=mathesar.${config.homelab.domain},127.0.0.1
POSTGRES_SSLMODE=require
POSTGRES_DB=${name}
POSTGRES_USER=${config.sops.placeholder.mathesar-postgres-user}
POSTGRES_PASSWORD=${config.sops.placeholder.mathesar-postgres-password}
POSTGRES_HOST=${config.sops.placeholder.mathesar-postgres-host}
POSTGRES_PORT=${toString config.sops.placeholder.mathesar-postgres-port}
SECRET_KEY="${config.sops.placeholder.mathesar-secret-key}
  '';
    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        mathesar = {
            image = dockerImage;
            autoStart = true;
            #ports = [ "127.0.0.1:${toString local_port}:8000" ];
            networks = ["host"];
            environmentFiles = [config.sops.templates."mathesar.env".path];
            environment = {
              OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://tempo-otlp-grpc.${config.homelab.domain}:443";
              OTEL_EXPORTER_OTLP_PROTOCOL="grpc";
              OTEL_SERVICE_NAME="et";
            };
        };
    };

    services.traefik.dynamicConfigOptions.http.routers.mathesar = mkIf cfg.expose_with_traefik {
        rule = "Host(`${name}.${config.homelab.domain}`)";
        service = "${name}@file";
    };
    services.traefik.dynamicConfigOptions.http.services.mathesar = mkIf cfg.expose_with_traefik {
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
