{ lib, config, pkgs, ... }:
let

  cfg = config.lab_et;
  name = "jellyfin";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );
  local_port = 8096;

in with lib; {
  options = {
    lab_jellyfin = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable jellyfin?
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
        "d /var/lib/${name}/ 0750 ${name} ${name} - "
        "d /var/lib/${name}/data 0750 ${name} ${name} - "
        "d /var/lib/${name}/cache 0750 ${name} ${name} - "
    ];
    services.rpcbind.enable = true; # needed for NFS

    systemd.mounts = [{
      type = "nfs";
      mountConfig = {
        Options = "noatime";
      };
      what = "192.168.1.212:/volume1/video";
      where = "/mnt/video";
    }];

    systemd.automounts = [{
      where = "/mnt/video";
    }];

    # optional, but ensures rpc-statsd is running for on demand mounting
    boot.supportedFilesystems = [ "nfs" ];

    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        jellyfin = {
            image = dockerImage;
            autoStart = true;
            # dependsOn = ["mnt-video.mount"];
            ports = [ "127.0.0.1:${toString local_port}:${toString local_port}" ];
            volumes =  [
                "/var/lib/${name}/data:/storage/data"
                "/var/lib/${name}/cache:/storage/cache"
                "/mnt/video/movies:/movies"
                "/mnt/video/tvshows:/tvshows"
                "/mnt/video/yt_tvshows:/youtube_shows"
            ];

            environment = {
              JELLYFIN_DATA_DIR = "/storage/data";
              JELLYFIN_CACHE_DIR = "/storage/cache";
              OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://tempo-otlp-grpc.${config.homelab.domain}:443";
              OTEL_EXPORTER_OTLP_PROTOCOL="grpc";
              OTEL_SERVICE_NAME="jellyfin";
            };
        };
    };

    services.traefik.dynamicConfigOptions.http.routers.jellyfin = mkIf cfg.expose_with_traefik {
        rule = "Host(`${name}.${config.homelab.domain}`)";
        service = "${name}@file";
    };
    services.traefik.dynamicConfigOptions.http.services.jellyfin = mkIf cfg.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:${toString local_port}";
          }
        ];
      };
    };

  };
}
