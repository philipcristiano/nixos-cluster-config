{ lib, config, pkgs, sops-nix, ... }:
with lib;
{
  imports = [
    ./parts/traefik.nix

    ./parts/anki-sync/service.nix
    ./parts/et/service.nix
  ];

  options = {
    homelab = {
      domain = mkOption {
        type = with types; uniq str;
        default = "home.cristiano.cloud";
        description = ''Domain to reach this server '';
      };
    };
  };

  config = {
    sops = {
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets = {
        "dnsimple_oauth_token" = {
          sopsFile = ../secrets/traefik.yaml;
          path = "/var/lib/traefik/dnsimple_oauth_token";
          key = "dnsimple_oauth_token";
          owner = "traefik";
          mode = "400";
        } ;
      };
    };

    sops.templates."/var/lib/traefik/dnsimple_oauth_token.env" = {
      content = ''
      DNSIMPLE_OAUTH_TOKEN=${config.sops.placeholder.dnsimple_oauth_token}
      '';
      path = "/var/lib/traefik/dnsimple_oauth_token";
      owner = "traefik";
    };

    services.traefik.environmentFiles = [config.sops.templates."/var/lib/traefik/dnsimple_oauth_token.env".path];

    lab_traefik.enable = true;
    lab_anki_sync.enable = true;
    services.traefik.dynamicConfigOptions.http.routers.router1 = {
      rule = "Host(`s1.${config.homelab.domain}`)";
      service = "service1";
    };
    services.traefik.dynamicConfigOptions.http.services.service1 = {
      loadBalancer = {
        servers = [
          {
            url = "http://localhost:8080";
          }
        ];
      };
    };
  };
}
