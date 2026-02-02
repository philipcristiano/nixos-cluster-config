
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_mimir;
  name = "mimir";


in with lib; {
  options = {
    lab_mimir = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable mimir?
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
  config = mkIf config.lab_mimir.enable {


    services.mimir.enable = true;
    services.mimir.configFile = config.sops.templates."mimir.yaml".path;

    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };

    sops.secrets.mimir_s3_endpoint = {
          sopsFile = secrets/${name}.yaml;
          key = "s3_endpoint";
          mode = "400";
          restartUnits = [ "mimir.service"];
    };
    sops.secrets.mimir_s3_bucket = {
          sopsFile = secrets/${name}.yaml;
          key = "s3_bucket";
          mode = "400";
          restartUnits = [ "mimir.service"];
    };
    sops.secrets.mimir_s3_access_key_id= {
          sopsFile = secrets/${name}.yaml;
          key = "s3_access_key_id";
          mode = "400";
          restartUnits = [];
    };
    sops.secrets.mimir_s3_secret_access_key = {
          sopsFile = secrets/${name}.yaml;
          key = "s3_secret_access_key";
          mode = "400";
          restartUnits = [];
    };
    sops.templates."mimir.yaml".owner = name;
    sops.templates."mimir.yaml".restartUnits = ["${name}.service"];
    sops.templates."mimir.yaml".content = ''

# Do not use this configuration in production.
# It is for demonstration purposes only.
# Run Mimir in single process mode, with all components running in 1 process.
target: all,alertmanager,overrides-exporter

# Only use a default tenant
multitenancy_enabled: false
# Configure Mimir to use Minio as object storage backend.
common:

  storage:
    backend: s3
    s3:
      endpoint: ${config.sops.placeholder.mimir_s3_endpoint}
      bucket_name: ${config.sops.placeholder.mimir_s3_bucket}
      access_key_id: ${config.sops.placeholder.mimir_s3_access_key_id}
      secret_access_key: ${config.sops.placeholder.mimir_s3_secret_access_key}


# Blocks storage requires a prefix when using a common object storage bucket.
blocks_storage:
  storage_prefix: blocks
  tsdb:
    dir: /var/lib/mimir/
    # Alloc dir is used for block storage. There is a chance this wont start up
    # again so flush the blocks when possible
    flush_blocks_on_shutdown: true

ingester:
  ring:
    replication_factor: 1

server:
  log_level: info
  # grpc_listen_address: 127.0.0.1
  grpc_listen_port: 9096
  http_listen_address: 127.0.0.1
  http_listen_port: 9080

memberlist:
  bind_port: 7947

limits:
  # Allow ingestion of out-of-order samples up to 5 minutes since the latest received sample for the series.
  out_of_order_time_window: 1m

  # (advanced) Most recent allowed cacheable result per-tenant, to prevent caching
  # very recent results that might still be in flux.
  # CLI flag: -query-frontend.max-cache-freshness
  max_cache_freshness: 2m

  # Delete blocks containing samples older than the specified retention period.
  # Also used by query-frontend to avoid querying beyond the retention period. 0
  # to disable.
  compactor_blocks_retention_period: 2500h


    '';

    systemd.tmpfiles.rules = [
        "d /var/lib/${name} 0750 ${name} ${name} - "
    ];

    services.traefik.dynamicConfigOptions.http.routers.mimir = mkIf config.lab_mimir.expose_with_traefik {
        rule = "Host(`mimir.${config.homelab.domain}`)";
        service = "mimir@file";
    };
    services.traefik.dynamicConfigOptions.http.services.mimir = mkIf config.lab_mimir.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:9080";
          }
        ];
      };
    };

  };
}
