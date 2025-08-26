
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_hello_idc;
  name = "hello_idc";
  dockerFile = builtins.readFile ./Dockerfile;
  dockerImage = pkgs.lib.trim( builtins.replaceStrings ["FROM "] [""] dockerFile );

in with lib; {
  options = {
    lab_hello_idc = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable hello_idc?
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
  config = mkIf config.lab_hello_idc.enable {

    environment.systemPackages = [];

    sops.secrets.hello_idc-client-secret = {
          sopsFile = secrets/hello_idc.yaml;
          key = "oidc_client_secret";
          mode = "400";
          restartUnits = ["docker-${name}.service"];
    };
    sops.secrets.hello_idc-client-id = {
          sopsFile = secrets/hello_idc.yaml;
          key = "oidc_client_id";
          mode = "400";
          restartUnits = ["docker-${name}.service"];
    };
    sops.secrets.hello_idc-key = {
          sopsFile = secrets/hello_idc.yaml;
          key = "key";
          mode = "400";
          restartUnits = ["docker-${name}.service"];
    };
    sops.templates."hello_idc.toml".owner = name;
    sops.templates."hello_idc.toml".content = ''

    [auth]
    issuer_url = "https://kanidm.${config.homelab.domain}/oauth2/openid/${config.sops.placeholder.hello_idc-client-id}"
    redirect_url = "https://hello_idc.${config.homelab.domain}/oidc/login_auth"
    client_secret = "${config.sops.placeholder.hello_idc-client-secret}"
    client_id = "${config.sops.placeholder.hello_idc-client-id}"
    key = "${config.sops.placeholder.hello_idc-key}"


  '';
    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        hello_idc = {
            image = dockerImage;
            autoStart = true;
            ports = [ "127.0.0.1:3007:3000" ];
            volumes =  ["${config.sops.templates."${name}.toml".path}:/etc/${name}.toml"];
            environment = {
              OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://tempo-otlp-grpc.${config.homelab.domain}:443";
              OTEL_EXPORTER_OTLP_PROTOCOL="grpc";
              OTEL_SERVICE_NAME=name;
            };
            cmd = ["--bind-addr=0.0.0.0:3000"
                   "--config-file=/etc/${name}.toml"];
        };
    };

    services.traefik.dynamicConfigOptions.http.routers.hello_idc = mkIf config.lab_hello_idc.expose_with_traefik {
        rule = "Host(`hello-idc.${config.homelab.domain}`)";
        service = "hello_idc@file";
    };
    services.traefik.dynamicConfigOptions.http.services.hello_idc = mkIf config.lab_hello_idc.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:3007";
          }
        ];
      };
    };
  };
}
