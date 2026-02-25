{ lib, config, pkgs, ... }:
with lib; {
  options = {
    lab_traefik = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable Traefik?
        '';
      };
    };
  };
  config = mkIf config.lab_traefik.enable {
    environment.systemPackages = [
      pkgs.traefik
    ];

    services.traefik = {

      enable = true;
      staticConfigOptions = {
        serversTransport.insecureSkipVerify = true;
        entryPoints = {
          web = {
            address = ":80";
            asDefault = true;
            http.redirections.entrypoint = {
              to = "websecure";
              scheme = "https";
            };
          };

          websecure = {
            address = ":443";
            asDefault = true;
            http.tls.certResolver = "letsencrypt";
            transport.respondingTimeouts = {
              readTimeout = "905s";
            };
          };

          postgres = {
            address = ":5431";
            asDefault = false;
            transport.respondingTimeouts = {
              readTimeout = "905s";
            };
          };
        };

        log = {
          level = "INFO";
          filePath = "${config.services.traefik.dataDir}/traefik.log";
          format = "json";
        };

        accessLog = {
          format = "json";
          filters = {
            statusCodes = ["300-302" "400-499" "500-599"];
            retryAttempts = true;
            minDuration = "100ms";
          };
        };

        certificatesResolvers.letsencrypt.acme = {
          email = "letsencrypt@philipcristiano.com";
          storage = "${config.services.traefik.dataDir}/acme.json";
          dnsChallenge.provider = "dnsimple";
        };

        api.dashboard = true;

        tracing.otlp.grpc.endpoint = "https://tempo-otlp-grpc.${config.homelab.domain}:443";
      };

      dynamicConfigOptions.http.routers.dashboard = {
        rule = "Host(`traefik.${config.homelab.domain}`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
        service = "api@internal";
      };
      dynamicConfigOptions.tls.options.default.alpnProtocols = [ "h2" "http/1.1" "postgresql" ];

    };
  };
}
