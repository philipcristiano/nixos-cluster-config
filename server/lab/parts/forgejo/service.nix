
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_forgejo;
  name = "forgejo";


in with lib; {
  options = {
    lab_forgejo = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable forgejo?
        '';
      };
      expose_with_traefik = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable exposing with traefik
        '';
      };
      local_http_port = mkOption {
        type = types.number;
        default = 3142;
        description = ''
          Local listen port
        '';
      };
      #use_docker_in_docker = mkOption {
      #  type = types.bool;
      #  default = true;
      #  description = ''
      #    Use docker-in-docker (should be enabled outside of this module)
      #  '';
      #};
    };
  };
  config = mkIf config.lab_forgejo.enable {
    sops.secrets.forgejo_runner_secret = {
        sopsFile = secrets/${name}.yaml;
        key = "runner_secret";
        mode = "400";
        restartUnits = [ "gitea-runner-default.service"];
    };
    sops.templates."forgejo-runner.env".owner = name;
    sops.templates."forgejo-runner.env".restartUnits = ["gitea-runner-default.service"];
    sops.templates."forgejo-runner.env".content = ''
TOKEN=${config.sops.placeholder.forgejo_runner_secret}
'';
    services.forgejo = {
        enable = true;
        database.type = "postgres";
        # Enable support for Git Large File Storage
        lfs.enable = true;
        settings = {
          server = {
            DOMAIN = "forgejo.${config.homelab.domain}/";
            # You need to specify this to remove the port from URLs in the web UI.
            ROOT_URL = "https://forgejo.${config.homelab.domain}/";
            HTTP_PORT = config.lab_forgejo.local_http_port;
          };
          # You can temporarily allow registration to create an admin user.
          service.DISABLE_REGISTRATION = false;
          # Add support for actions, based on act: https://github.com/nektos/act
          actions = {
            ENABLED = true;
            DEFAULT_ACTIONS_URL = "github";
          };
        };
        #secrets = {
        #  mailer.PASSWD = config.age.secrets.forgejo-mailer-password.path;
        #};
    };
    services.gitea-actions-runner = {
        package = pkgs.forgejo-actions-runner;
        instances.default = {
          enable = true;
          name = "monolith";
          url = "https://forgejo.${config.homelab.domain}/";

          # Obtaining the path to the runner token file may differ
          # tokenFile should be in format TOKEN=<secret>, since it's EnvironmentFile for systemd
          settings = {
              runner = {
                  envs = {
                      "DOCKER_HOST" = "tcp://docker_in_docker.docker.internal:${toString config.lab_docker_in_docker.docker_port}";

                  };
              };
              container = {
                  docker_host = "tcp://127.0.0.1:${toString config.lab_docker_in_docker.local_port}";
                  option = "--add-host=docker_in_docker.docker.internal:host-gateway";

              };
          };
          tokenFile = config.sops.templates."forgejo-runner.env".path;
          labels = [
            "ubuntu-latest:docker://node:16-bullseye"
            "ubuntu-22.04:docker://node:16-bullseye"
            "ubuntu-20.04:docker://node:16-bullseye"
            "ubuntu-18.04:docker://node:16-buster"
            ## optionally provide native execution on the host:
            # "native:host"
            ];
      };
    };
    systemd.services."gitea-runner-default".requires = [
      "docker-docker_in_docker.service"
    ];
    systemd.services."gitea-runner-default".after = [
      "docker-docker_in_docker.service"
    ];
    services.traefik.dynamicConfigOptions.http.routers.forgejo = mkIf config.lab_forgejo.expose_with_traefik {
        rule = "Host(`forgejo.${config.homelab.domain}`)";
        service = "forgejo@file";
    };
    services.traefik.dynamicConfigOptions.http.services.forgejo = mkIf config.lab_forgejo.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:${toString config.lab_forgejo.local_http_port}";
          }
        ];
      };
    };

  };
}
