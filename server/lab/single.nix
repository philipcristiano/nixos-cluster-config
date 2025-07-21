{ lib, config, pkgs, sops-nix, ... }:
with lib;
{
  imports = [
    ./parts/traefik.nix

    ./parts/restic-s3/service.nix
    ./parts/postgres/service.nix
    ./parts/anki-sync/service.nix
    ./parts/et/service.nix
    ./parts/miniflux/service.nix
    ./parts/rotki/service.nix
    ./parts/w2z/service.nix
    ./parts/paperless/service.nix
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
    lab_restic_s3.enable = true;
    lab_anki_sync.enable = true;
    lab_et.enable = true;
    lab_miniflux.enable = true;
    lab_rotki.enable = true;
    lab_w2z.enable = true;
    lab_paperless.enable = true;
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
