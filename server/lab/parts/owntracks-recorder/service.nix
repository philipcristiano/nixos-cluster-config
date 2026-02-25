{ lib, config, pkgs, ... }:
let

  cfg = config.lab_owntracks_recorder;
  name = "owntracks-recorder";
  local_port = 8034;
  unit_name = "${name}.service";

in with lib; {
  options = {
    lab_owntracks_recorder = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable Owntracks Recorder?
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
    sops.secrets.owntracks_recorder_mqtt_host = {
        sopsFile = secrets/${name}.yaml;
        key = "mqtt_host";
        mode = "400";
        restartUnits = [unit_name];
    };
    sops.secrets.owntracks_recorder_mqtt_user = {
        sopsFile = secrets/${name}.yaml;
        key = "mqtt_user";
        mode = "400";
        restartUnits = [unit_name];
    };
    sops.secrets.owntracks_recorder_mqtt_password = {
        sopsFile = secrets/${name}.yaml;
        key = "mqtt_password";
        mode = "400";
        restartUnits = [unit_name];
    };

    sops.templates."owntracks-recorder.env" = {
      owner = name;
      group = name;
      content = ''

OTR_HOST=${config.sops.placeholder.owntracks_recorder_mqtt_host}
OTR_USER=${config.sops.placeholder.owntracks_recorder_mqtt_user}
OTR_PASS=${config.sops.placeholder.owntracks_recorder_mqtt_password}
OTR_STORAGEDIR=/var/lib/${name}
      '';
    };

    systemd.services.owntracks-recorder = {
      description = "owntracks recorder";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.owntracks-recorder ];
      environment = { };
      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = name;
        EnvironmentFile = config.sops.templates."owntracks-recorder.env".path;
        User = name;
        ExecStart = "${pkgs.owntracks-recorder}/bin/ot-recorder --http-port=${toString local_port} owntracks/#";
        Restart = "always";
      };
    };
    services.restic.backups.persist.paths = ["/var/lib/${name}"];
#
    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };

    systemd.tmpfiles.rules = [
        "d /var/lib/${name} 0700 ${name} ${name} - "
    ];

    services.traefik.dynamicConfigOptions.http.routers.${name} = mkIf cfg.expose_with_traefik {
        rule = "Host(`${name}.${config.homelab.domain}`)";
        entrypoints = "websecure";
        service = "${name}@file";
    };

    services.traefik.dynamicConfigOptions.http.services.${name} = mkIf cfg.expose_with_traefik {
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
