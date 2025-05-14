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
          };
        };


        log = {
          level = "INFO";
          filePath = "${config.services.traefik.dataDir}/traefik.log";
          format = "json";
        };

        certificatesResolvers.letsencrypt.acme = {
          email = "letsencrypt@philipcristiano.com";
          storage = "${config.services.traefik.dataDir}/acme.json";
          dnsChallenge.provider = "dnsimple";
        };

        api.dashboard = true;
        # Access the Traefik dashboard on <Traefik IP>:8080 of your server
        # api.insecure = true;
      };

      dynamicConfigOptions.http.routers.dashboard = {
        rule = "Host(`traefik.${config.homelab.domain}`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
        service = "api@internal";
      };

    };
  };
}
