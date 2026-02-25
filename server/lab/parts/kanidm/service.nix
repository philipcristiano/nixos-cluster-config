{ lib, config, pkgs, ... }:
let

  cfg = config.lab_kanidm;
  name = "kanidm";
  local_port = 8032;
  ldap_port = 8033;

in with lib; {
  options = {
    lab_kanidm = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable kanidm?
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


    sops.templates."dnsimple_oauth_token.env" = {
      content = ''
      DNSIMPLE_OAUTH_TOKEN=${config.sops.placeholder.dnsimple_oauth_token}
      '';
    };


    security.acme = {
      acceptTerms = true;
      defaults.email = "letsencrypt@philipcristiano.com";
      certs."kanidm.${config.homelab.domain}" = {
        dnsProvider = "dnsimple";
        environmentFile = config.sops.templates."dnsimple_oauth_token.env".path;
        group = name;
        extraDomainNames = ["127.0.0.1"];
      };
    };

    services.kanidm = {
      enableServer = true;
      package = pkgs.kanidm_1_8;
      serverSettings = {
        bindaddress = "127.0.0.1:${toString local_port}";
        ldapbindaddress = "127.0.0.1:${toString ldap_port}";
        domain = "kanidm.${config.homelab.domain}";
        log_level = "info";
        tls_chain = "/var/lib/acme/kanidm.${config.homelab.domain}/fullchain.pem";
        tls_key = "/var/lib/acme/kanidm.${config.homelab.domain}/key.pem";
        trust_x_forward_for = true;
        origin = "https://kanidm.${config.homelab.domain}";
        online_backup = {
          versions = 2;
          schedule = "@daily";
          path = "/var/lib/${name}/backups/";
        };
      };
    };
    systemd.services."kanidm.service".after = ["acme-kanidm.${config.homelab.domain}.service"];
    systemd.services."kanidm.service".requires = ["acme-kanidm.${config.homelab.domain}.service"];
    services.restic.backups.persist.paths = ["/var/lib/${name}/backups"];
#
    # users.groups."${name}" = {};
    # users.users."${name}" = {
    #   group = name;
    #   isSystemUser = true;
    # };

    systemd.tmpfiles.rules = [
        "d /var/lib/${name} 0700 ${name} ${name} - "
    ];

    services.traefik.dynamicConfigOptions.http.routers.kanidm = mkIf cfg.expose_with_traefik {
        rule = "Host(`${name}.${config.homelab.domain}`)";
        entrypoints = "websecure";
        service = "${name}@file";
        tls = {
           #passthrough = true;
        };
    };
    # TODO: this should be scoped just to the kanidm backend
    services.traefik.staticConfigOptions.serversTransport.insecureSkipVerify = true;

    services.traefik.dynamicConfigOptions.http.services.kanidm = mkIf cfg.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "https://127.0.0.1:${toString local_port}";
          }
        ];
      };
    };

    services.traefik.dynamicConfigOptions.tcp.routers.kanidm_ldap = mkIf cfg.expose_with_traefik {
        entrypoints = "ldap";
        rule = "HostSNI(`ldap.${config.homelab.domain}`)";
        service = "kanidm_ldap@file";
        tls.passthrough = true;
    };
    services.traefik.dynamicConfigOptions.tcp.services.kanidm_ldap = mkIf cfg.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            address = "127.0.0.1:${toString ldap_port}";
          }
        ];
      };
    };

  };
}
