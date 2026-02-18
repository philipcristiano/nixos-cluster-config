
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_radicle;
  name = "radicle";


in with lib; {
  options = {
    lab_radicle = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable radicle?
        '';
      };
      enable_http = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable radicle http interface?
        '';
      };
      enable_native_ci = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable radicle native ci?
        '';
      };
      expose_http_with_traefik = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable exposing with traefik
        '';
      };
    };
  };
  config = mkIf config.lab_radicle.enable {
    sops.secrets.radicle_private_key = {
          sopsFile = secrets/radicle.yaml;
          key = "private_key";
          mode = "400";
          restartUnits = ["radicle-node.service"];
          owner = name;
    };
    sops.secrets.radicle_public_key = {
          sopsFile = secrets/radicle.yaml;
          key = "public_key";
          mode = "400";
          restartUnits = ["radicle-node.service"];
          owner = name;
    };

    services.radicle = {
        enable = true;
        privateKeyFile = config.sops.secrets.radicle_private_key.path;
        publicKey = config.sops.secrets.radicle_public_key.path;
        node.openFirewall = true;
        node.listenAddress = "0.0.0.0";
        node.listenPort = 8776;

        httpd.enable = config.lab_radicle.enable_http;
    };

    services.radicle.settings = {
        node.alias = "hazzard";
        node.log = "DEBUG";
        seedingPolicy.default = "block";
    };

    users.groups."${name}" = { };
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
      extraGroups = ["docker"];
    };

    services.nginx = {
        enable = config.lab_radicle.enable_native_ci;

        virtualHosts."ci.${config.homelab.domain}" = {
            root = "/var/lib/radicle-ci/reports";
            listen = [
                {addr = "0.0.0.0";
                 port = 8001;
            }
            ];
            locations."/adapters/" = {
                root = "/var/lib/radicle-ci/";
            };
        };
    };
    services.traefik.dynamicConfigOptions.http.routers.ci = mkIf config.lab_radicle.enable_native_ci {
        rule = "Host(`ci.${config.homelab.domain}`)";
        service = "ci@file";
    };
    services.traefik.dynamicConfigOptions.http.services.ci = mkIf config.lab_radicle.enable_native_ci {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:8001";
          }
        ];
      };
    };

    services.radicle.ci = mkIf (config.lab_radicle.enable_native_ci) {
        broker.enable = true;
        broker.settings = {
          adapters.native = {
            command = lib.getExe pkgs.radicle-native-ci;
            config = { };
            config_env = "RADICLE_NATIVE_CI";
            #env.PATH = lib.makeBinPath (with pkgs; [ bash coreutils ]);
          };

          triggers = [
            {
              adapter = "native";
              filters = [
                {
                  And = [
                    { HasFile = ".radicle/native.yaml"; }
                    { Or =  [
                        { Node = "z6Mkr8mq1Ji1rH1yY81dpnWdVBLzMiwroPwLBMi72GoyRH5Y"; }
                        { Node = "z6Mkm2rZRiLM8Xvb48Fsnrs5iLZ7eu8Rr8wuooyTW4re3o1c"; }
                        ];
                    }
                    {
                      Or = [
                        "DefaultBranch"
                        "PatchCreated"
                        "PatchUpdated"
                      ];
                    }
                  ];
                }
              ];
            }
          ];
        };
        adapters.native.instances = {
            native = {
                enable = true;
                settings.base_url = "/adapters/native/native/";
                runtimePackages = [
                    pkgs.bash
                    pkgs.coreutils
                    pkgs.curl
                    pkgs.docker
                    pkgs.gawk
                    pkgs.gitMinimal
                    pkgs.gnused
                    pkgs.nix
                    pkgs.wget
                ];
            };
        };

    };
    systemd.tmpfiles.rules = [
        #"d /var/log/radicle-ci/adapters/ 0750 ${name} ${name} - "
        "a+ /var/lib/radicle-ci/adapters/native/native - - - - d:u:nginx:r-X,u:nginx:r-X"
    ];
    services.traefik.dynamicConfigOptions.http.routers.${name} = mkIf config.lab_radicle.expose_http_with_traefik {
        rule = "Host(`radicle.${config.homelab.domain}`)";
        service = "radicle@file";
    };
    services.traefik.dynamicConfigOptions.http.services.${name} = mkIf config.lab_radicle.expose_http_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:${toString config.services.radicle.httpd.listenPort}";
          }
        ];
      };
    };
  };
}
