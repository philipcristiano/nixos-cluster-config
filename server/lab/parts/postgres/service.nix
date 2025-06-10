{ lib, config, pkgs, ... }:
let

in with lib; {
  options = {
    lab_postgres = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable postgres service?
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
  config = mkIf config.lab_postgres.enable {
    services.postgresql.enable = true;
    services.postgresql.package = pkgs.postgresql_17;


    services.postgresqlBackup = {
      enable = true;
      backupAll = true;
    };

    services.traefik.dynamicConfigOptions.http.services.postgres = mkIf config.lab_postgres.expose_with_traefik {
      loadBalancer = {
        servers = [
          {
            url = "tcp://127.0.0.1:5432";
          }
        ];
      };
    };
  };
}
