
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_loki;
  name = "loki";


in with lib; {
  options = {
    lab_loki = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable loki?
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
  config = mkIf config.lab_loki.enable {


    services.loki.enable = true;
    services.loki.configFile = config.sops.templates."loki.yaml".path;

    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };

    sops.secrets.loki_s3_endpoint = {
          sopsFile = secrets/${name}.yaml;
          key = "s3_endpoint";
          mode = "400";
          restartUnits = [ "loki.service"];
    };
    sops.secrets.loki_s3_bucket = {
          sopsFile = secrets/${name}.yaml;
          key = "s3_bucket";
          mode = "400";
          restartUnits = [ "loki.service"];
    };
    sops.secrets.loki_s3_access_key_id= {
          sopsFile = secrets/${name}.yaml;
          key = "s3_access_key_id";
          mode = "400";
          restartUnits = [];
    };
    sops.secrets.loki_s3_secret_access_key = {
          sopsFile = secrets/${name}.yaml;
          key = "s3_secret_access_key";
          mode = "400";
          restartUnits = [];
    };
    sops.templates."loki.yaml".owner = name;
    sops.templates."loki.yaml".content = ''

auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9097
#
# Minio Storage
#

storage_config:
  aws:
    access_key_id: ${config.sops.placeholder.loki_s3_access_key_id}
    secret_access_key: ${config.sops.placeholder.loki_s3_secret_access_key}
    s3: "${config.sops.placeholder.loki_s3_endpoint}/${config.sops.placeholder.loki_s3_bucket}"
    s3forcepathstyle: true

  tsdb_shipper:
    active_index_directory: /var/lib/loki/tsdb-index
    cache_location: /var/lib/loki/tsdb-cache
    # index_gateway_client:
    #   # only applicable if using microservices where index-gateways are independently deployed.
    #   # This example is using kubernetes-style naming.
    #   server_address: dns:///index-gateway.<namespace>.svc.cluster.local:9095

common:
  path_prefix: /var/lib/loki
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: aws
      schema: v12
      index:
        prefix: index_
        period: 24h
    - from: 2024-04-04
      store: tsdb
      object_store: aws
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 7d
  split_queries_by_interval: 24h

frontend:
  max_outstanding_per_tenant: 4096

ruler:
  alertmanager_url: http://localhost:9093

    '';

    systemd.tmpfiles.rules = [
        "d /var/lib/${name} 0750 ${name} ${name} - "
    ];

    services.traefik.dynamicConfigOptions.http.routers.loki = mkIf config.lab_loki.expose_with_traefik {
        rule = "Host(`loki.${config.homelab.domain}`)";
        service = "loki@file";
    };
    services.traefik.dynamicConfigOptions.http.services.loki = mkIf config.lab_loki.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:3100";
          }
        ];
      };
    };
  };
}
