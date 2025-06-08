
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_w2z;
  name = "w2z";
  w2zFlake = builtins.getFlake "github:philipcristiano/w2z/5e2fd4d40220a5e4ee8e93dbc93d14a2f0052dfe";
  w2zPackage = w2zFlake.packages.${pkgs.system}.default;

in with lib; {
  options = {
    lab_w2z = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable w2z?
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
  config = mkIf config.lab_w2z.enable {

    environment.systemPackages = [];

    sops.secrets.w2z-client-secret = {
          sopsFile = secrets/w2z.yaml;
          key = "oidc_client_secret";
          mode = "400";
          restartUnits = ["w2z.service"];
    };
    sops.secrets.w2z-client-id = {
          sopsFile = secrets/w2z.yaml;
          key = "oidc_client_id";
          mode = "400";
          restartUnits = ["w2z.service"];
    };
    sops.secrets.w2z-github-app-id = {
          sopsFile = secrets/w2z.yaml;
          key = "github_app_id";
          mode = "400";
          restartUnits = ["w2z.service"];
    };
    sops.secrets.w2z-github-app-key = {
          sopsFile = secrets/w2z.yaml;
          key = "github_app_key";
          mode = "400";
          restartUnits = ["w2z.service"];
    };
    sops.secrets.w2z-key = {
          sopsFile = secrets/w2z.yaml;
          key = "key";
          mode = "400";
          restartUnits = ["w2z.service"];
    };
    sops.templates."w2z.toml".owner = name;
    sops.templates."w2z.toml".content = ''

    [auth]
    issuer_url = "https://kanidm.${config.homelab.domain}/oauth2/openid/${config.sops.placeholder.w2z-client-id}"
    redirect_url = "https://w2z.${config.homelab.domain}/oidc/login_auth"
    client_secret = "${config.sops.placeholder.w2z-client-secret}"
    client_id = "${config.sops.placeholder.w2z-client-id}"
    key = "${config.sops.placeholder.w2z-key}"

    [github]
    app_id = ${config.sops.placeholder.w2z-github-app-id}
    app_key = """${config.sops.placeholder.w2z-github-app-key}"""
    owner = "philipcristiano"
    repository = "philipcristiano.com"
    branch = "main"

    [templates]
    [templates.note]
    path = "content/notes/{{ now() | date(format=\"%Y/%Y%m%d%H%M%S\")}}/index.md"
    body = """
    +++
    date = "{{ now() | date(format=\"%Y-%m-%dT%H:%M:%SZ\")}}"
    +++

    {{contents}}
    """

    [templates.reply]
    path = "content/replies/{{ now() | date(format=\"%Y/%Y%m%d%H%M%S\")}}/index.md"
    body = """
    +++
    date = "{{ now() | date(format=\"%Y-%m-%dT%H:%M:%SZ\")}}"
    [extra]
    in_reply_to = "{{in_reply_to}}"
    +++

    {{contents}}
    """

    [templates.like]
    path = "content/likes/{{ now() | date(format=\"%Y/%Y%m%d%H%M%S\")}}/index.md"
    body = """
    +++
    date = "{{ now() | date(format=\"%Y-%m-%dT%H:%M:%SZ\")}}"
    [extra]
    in_like_of = "{{in_like_of}}"
    +++

    {{contents}}
    """

  '';
    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers = {
        w2z = {
            image = "philipcristiano/w2z:0.10.3";
            autoStart = true;
            ports = [ "127.0.0.1:3003:3000" ];
            volumes =  ["${config.sops.templates."w2z.toml".path}:/etc/w2z.toml"];
            cmd = ["--bind-addr=0.0.0.0:3000"
                   "--config-file=/etc/w2z.toml"];
        };
    };

    # systemd.services.w2z = {
    #   description = "w2z";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   path = [ w2zPackage ];
    #   environment = { };
    #   serviceConfig = {
    #     Type = "simple";
    #     DynamicUser = true;
    #     StateDirectory = name;
    #     User = name;
    #     ExecStart = "${w2zPackage}/bin/w2z --config-file ${config.sops.templates."w2z.toml".path} --bind-addr=0.0.0.0:3003";
    #     Restart = "always";
    #   };
    # };

    services.traefik.dynamicConfigOptions.http.routers.w2z = mkIf config.lab_w2z.expose_with_traefik {
        rule = "Host(`w2z.${config.homelab.domain}`)";
        service = "w2z@file";
    };
    services.traefik.dynamicConfigOptions.http.services.w2z = mkIf config.lab_w2z.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:3003";
          }
        ];
      };
    };
  };
}
