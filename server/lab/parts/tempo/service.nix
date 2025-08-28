
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_tempo;
  name = "tempo";


in with lib; {
  options = {
    lab_tempo = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable tempo?
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
  config = mkIf config.lab_tempo.enable {


    services.tempo.enable = true;
    services.tempo.configFile = config.sops.templates."tempo.yaml".path;

    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };

    sops.secrets.tempo_s3_endpoint = {
          sopsFile = secrets/${name}.yaml;
          key = "s3_endpoint";
          mode = "400";
          restartUnits = [ "tempo.service"];
    };
    sops.secrets.tempo_s3_bucket = {
          sopsFile = secrets/${name}.yaml;
          key = "s3_bucket";
          mode = "400";
          restartUnits = [ "tempo.service"];
    };
    sops.secrets.tempo_s3_access_key_id= {
          sopsFile = secrets/${name}.yaml;
          key = "s3_access_key_id";
          mode = "400";
          restartUnits = [];
    };
    sops.secrets.tempo_s3_secret_access_key = {
          sopsFile = secrets/${name}.yaml;
          key = "s3_secret_access_key";
          mode = "400";
          restartUnits = [];
    };
    sops.templates."tempo.yaml".owner = name;
    sops.templates."tempo.yaml".content = ''

server:
  http_listen_port: 4244

query_frontend:
  search:
    duration_slo: 5s
    throughput_bytes_slo: 1.073741824e+09
  trace_by_id:
    duration_slo: 5s

distributor:
  receivers:                           # this configuration will listen on all ports and protocols that tempo is capable of.
    jaeger:                            # the receives all come from the OpenTelemetry collector.  more configuration information can
      protocols:                       # be found there: https://github.com/open-telemetry/opentelemetry-collector/tree/main/receiver
        thrift_http:                   #
        grpc:                          # for a production deployment you should only enable the receivers you need!
        thrift_binary:
        thrift_compact:
    zipkin:
    otlp:
      protocols:
        http:
        grpc:
    opencensus:


storage:
  trace:
    backend: s3                        # backend configuration to use
    wal:
      path: /var/lib/tempo/wal             # where to store the the wal locally
    s3:
      bucket: ${config.sops.placeholder.tempo_s3_bucket}
      endpoint: ${config.sops.placeholder.tempo_s3_endpoint}
      access_key: ${config.sops.placeholder.tempo_s3_access_key_id}
      secret_key: ${config.sops.placeholder.tempo_s3_secret_access_key}

compactor:
  compaction:
    block_retention: 72h

    '';

    systemd.tmpfiles.rules = [
        "d /var/lib/${name} 0750 ${name} ${name} - "
    ];

    services.traefik.dynamicConfigOptions.http.routers.tempo = mkIf config.lab_tempo.expose_with_traefik {
        rule = "Host(`tempo.${config.homelab.domain}`)";
        service = "tempo@file";
    };
    services.traefik.dynamicConfigOptions.http.services.tempo = mkIf config.lab_tempo.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:4244";
          }
        ];
      };
    };

    services.traefik.dynamicConfigOptions.http.routers.tempo_otlp_grpc = mkIf config.lab_tempo.expose_with_traefik {
        rule = "Host(`tempo-otlp-grpc.${config.homelab.domain}`)";
        service = "tempo_otlp_grpc@file";
    };
    services.traefik.dynamicConfigOptions.http.services.tempo_otlp_grpc = mkIf config.lab_tempo.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "h2c://127.0.0.1:4317";
          }
        ];
      };
    };

    services.traefik.dynamicConfigOptions.http.routers.tempo_otlp_http = mkIf config.lab_tempo.expose_with_traefik {
        rule = "Host(`tempo-otlp-http.${config.homelab.domain}`)";
        service = "tempo_otlp_http@file";
    };
    services.traefik.dynamicConfigOptions.http.services.tempo_otlp_http = mkIf config.lab_tempo.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:4318";
          }
        ];
      };
    };



  };
}
