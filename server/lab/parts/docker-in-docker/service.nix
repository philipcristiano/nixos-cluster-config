

{ lib, config, pkgs, ... }:
let

  cfg = config.lab_docker_in_docker;
  name = "docker_in_docker";


in with lib; {
  options = {
    lab_docker_in_docker = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable Docker in Docker?
        '';
      };
      docker_port = mkOption {
        type = types.number;
        default = 2375;
        description = ''
          Local listen port
        '';
      };
      local_port = mkOption {
        type = types.number;
        default = 2376;
        description = ''
          Local listen port
        '';
      };
      docker_image = mkOption {
        type = types.string;
        default = "docker:dind";
        description = ''
            Docker image to use for dind
        '';
      };
    };

  };

  config = mkIf config.lab_docker_in_docker.enable {
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        docker_in_docker = {
            image = config.lab_docker_in_docker.docker_image;
            autoStart = true;
            ports = [ "127.0.0.1:${toString config.lab_docker_in_docker.local_port}:${toString config.lab_docker_in_docker.docker_port}" ];
            #networks = ["host"];
            privileged = true;
            cmd = ["dockerd"
                    "-H tcp://0.0.0.0:${toString config.lab_docker_in_docker.docker_port}"
                    "--tls=false"
            ];
        };
    };
    systemd.services."docker-docker_in_docker.service".wantedBy = ["gitea-runner-default.service"];

  };
}
