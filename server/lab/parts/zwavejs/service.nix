
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_zwavejs;
  name = "zwavejs";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );

in with lib; {
  options = {
    lab_zwavejs = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable zwavejs?
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
  config = mkIf config.lab_zwavejs.enable {

    environment.systemPackages = [];

    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        zwavejs = {
            image = dockerImage;
            autoStart = true;
            ports = [ "127.0.0.1:3017:8091"
                      "127.0.0.1:3018:3000" ];
            volumes =  ["/var/lib/${name}:/usr/src/app/store"];
            devices = [
                "/dev/ttyACM0:/dev/ttyACM0"
            ];
            environment = {
              OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://tempo-otlp-grpc.${config.homelab.domain}:443";
              OTEL_EXPORTER_OTLP_PROTOCOL="grpc";
              OTEL_SERVICE_NAME="zwavejs";
            };
        };
    };

    systemd.services.docker-zwavejs = {
      unitConfig = {
        # Don't hit a limit for number of restarts
        StartLimitIntervalSec=0;
      };
      serviceConfig = {
        # Don't try to restart too quickly when there is a problem
        RestartSec=5;

      };
    };

    systemd.tmpfiles.rules = [
        "d /var/lib/${name} 0750 ${name} ${name} - "
    ];

    services.traefik.dynamicConfigOptions.http.routers.zwavejs = mkIf config.lab_zwavejs.expose_with_traefik {
        rule = "Host(`zwavejs.${config.homelab.domain}`)";
        service = "zwavejs@file";
    };
    services.traefik.dynamicConfigOptions.http.services.zwavejs = mkIf config.lab_zwavejs.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:3017";
          }
        ];
      };
    };
    services.traefik.dynamicConfigOptions.http.routers.zwavejs-websocket = mkIf config.lab_zwavejs.expose_with_traefik {
        rule = "Host(`zwavejs-websocket.${config.homelab.domain}`)";
        service = "zwavejs-websocket@file";
    };
    services.traefik.dynamicConfigOptions.http.services.zwavejs-websocket = mkIf config.lab_zwavejs.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:3018";
          }
        ];
      };
    };
  };
}
