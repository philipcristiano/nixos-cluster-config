
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_et;
  name = "et";
  etFlake = builtins.getFlake "github:philipcristiano/et/95186c88422f2db1c04f82471ed28cbb4f531aab";
  etPackage = etFlake.packages.${pkgs.system}.default;

in with lib; {
  options = {
    lab_et = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable et?
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
  config = mkIf config.lab_et.enable {

    environment.systemPackages = [
      pkgs.et
    ];

    sops.secrets.et-key = {
          sopsFile = secrets/et.yaml;
          key = "key";
          mode = "400";
          restartUnits = ["et.service"];
    };

    systemd.services.et = {
      description = "et: Expense Tacker";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ etPackage ];
      environment = { };
      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = name;
        ExecStart = "et";
        Restart = "always";
      };
    };

    services.traefik.dynamicConfigOptions.http.routers.et = mkIf config.lab_et.expose_with_traefik {
        rule = "Host(`et.${config.homelab.domain}`)";
        service = "et@file";
    };
    services.traefik.dynamicConfigOptions.http.services.et = mkIf config.lab_et.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "http://127.0.0.1:3002";
          }
        ];
      };
    };
  };
}
