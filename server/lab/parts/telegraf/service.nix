
{ lib, config, pkgs, ... }:
let

  cfg = config.lab_telegraf;
  name = "telegraf";

in with lib; {
  options = {
    lab_telegraf = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable telegraf?
        '';
      };
    };
  };
  config = mkIf config.lab_telegraf.enable {

    services.telegraf.enable = true;

    users.groups."${name}" = {};
    users.users."${name}" = {
      group = name;
      isSystemUser = true;
    };


    services.telegraf.extraConfig =
    {
        inputs = {};
        outputs = {
            http = {
                url = "https://mimir.${config.homelab.domain}/api/v1/push";

                metric_buffer_limit = 50000;
                data_format = "prometheusremotewrite";
                headers = {
                    "Content-Type" = "application/x-protobuf";
                    "Content-Encoding" = "snappy";
                    "X-Prometheus-Remote-Write-Version" = "0.1.0";
                };
            };
        };
    };

  };
}
