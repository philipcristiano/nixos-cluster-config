{ lib, config, pkgs, ... }:
let
  cfg = config.lab_restic_s3;

in with lib; {
  options = {
    lab_restic_s3 = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable restic backups to s3?
        '';
      };
    };
  };
  config = mkIf cfg.enable {
    # services.restic.enable = true;

    sops.secrets.restic_s3_password = {
          sopsFile = secrets/restic.yaml;
          key = "password";
          mode = "400";
          restartUnits = [];
    };
    sops.secrets.restic_s3_access_key_id= {
          sopsFile = secrets/restic.yaml;
          key = "access_key_id";
          mode = "400";
          restartUnits = [];
    };

    sops.secrets.restic_s3_secret_access_key = {
          sopsFile = secrets/restic.yaml;
          key = "secret_access_key";
          mode = "400";
          restartUnits = [];
    };

    sops.secrets.restic_s3_repository = {
          sopsFile = secrets/restic.yaml;
          key = "repository";
          mode = "400";
          restartUnits = [];
    };

    sops.templates."restic-s3.env".content = ''
    AWS_ACCESS_KEY_ID=${config.sops.placeholder.restic_s3_access_key_id}
    AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.restic_s3_secret_access_key}
    '';

    services.restic.backups = {
        persist = {
          user = "root";
          initialize = true;
          passwordFile = config.sops.secrets."restic_s3_password".path;
          timerConfig = {
            OnCalendar = "*-*-* 02:00:00";
            Persistent = true;
          };
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 3"
          ];
          repositoryFile = config.sops.secrets.restic_s3_repository.path;
          environmentFile = config.sops.templates."restic-s3.env".path;
        };
    };

  };
}
