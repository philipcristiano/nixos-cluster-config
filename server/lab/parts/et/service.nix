{ lib, config, pkgs, ... }:
let

  cfg = config.lab_et;
  name = "et";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );

in with lib; {
  options = {
    lab_et = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable et?
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

    sops.secrets.et-databaseurl-secret = {
          sopsFile = secrets/et.yaml;
          key = "database_url";
          mode = "400";
          restartUnits = ["docker-et-migrate.service" "docker-et.service"];
    };
    sops.secrets.et-client-id = {
          sopsFile = secrets/et.yaml;
          key = "oidc_client_id";
          mode = "400";
          restartUnits = ["docker-et.service"];
    };
    sops.secrets.et-client-secret = {
          sopsFile = secrets/et.yaml;
          key = "oidc_client_secret";
          mode = "400";
          restartUnits = ["docker-et.service"];
    };
    sops.secrets.et-key = {
          sopsFile = secrets/et.yaml;
          key = "key";
          mode = "400";
          restartUnits = ["docker-et.service"];
    };
    sops.templates."et.toml".owner = name;
    sops.templates."et.toml".content = ''
    database_url="${config.sops.placeholder.et-databaseurl-secret}"

    [auth]
    issuer_url = "https://kanidm.${config.homelab.domain}/oauth2/openid/${config.sops.placeholder.et-client-id}"
    redirect_url = "https://${name}.${config.homelab.domain}/oidc/login_auth"
    client_id = "${config.sops.placeholder.et-client-id}"
    client_secret = "${config.sops.placeholder.et-client-secret}"
    key = "${config.sops.placeholder.et-key}"

    [features]
    charts = true

  '';
    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        et-migrate = {
            image = dockerImage;
            #ports = [ "127.0.0.1:3002:3000" ];
            volumes =  ["${config.sops.templates."et.toml".path}:/etc/et.toml"];
            entrypoint = "et-migrate";
            networks = ["host"];
            #autoRemoveOnStop = false;
            cmd = ["--config-file=/etc/et.toml"
                   "migrate"];
        };
        et = {
            image = dockerImage;
            dependsOn = [ "et-migrate" ];
            autoStart = true;
            #ports = [ "127.0.0.1:3002:3000" ];
            volumes =  ["${config.sops.templates."et.toml".path}:/etc/et.toml"];
            networks = ["host"];
            cmd = ["--bind-addr=0.0.0.0:3002"
                   "--config-file=/etc/et.toml"];
        };
    };
    systemd.services.docker-et-migrate.serviceConfig.Restart = lib.mkForce "on-failure";
    systemd.services.docker-et-migrate.serviceConfig.Type = "oneshot";
    systemd.services.docker-et-migrate.serviceConfig.RemainAfterExit = true;

    services.traefik.dynamicConfigOptions.http.routers.et = mkIf cfg.expose_with_traefik {
        rule = "Host(`${name}.${config.homelab.domain}`)";
        service = "${name}@file";
    };
    services.traefik.dynamicConfigOptions.http.services.et = mkIf cfg.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:3002";
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
