{ config, pkgs, ... }:

{ environment.systemPackages = [ pkgs.cni-plugins
                                 pkgs.consul
                                 pkgs.nomad
                                 pkgs.vault];
  services.consul.enable = true;
  services.consul.extraConfig = {
        server = true;
        bootstrap_expect = 3;
        ca_file = "/etc/consul.d/consul-agent-ca.pem";
        cert_file = "/etc/consul.d/dc1-server-consul.pem";
        key_file = "/etc/consul.d/dc1-server-consul-key.pem";
        auto_encrypt = {
            allow_tls = true;
        };
        retry_join     = [ "192.168.102.100" "192.168.102.101" "192.168.102.102" ];
        acl  = {
            enabled = false;
            default_policy = "allow";
            enable_token_persistence = true;
        };
  };

  # systemd.services.consul.serviceConfig.Type = "notify";

  environment.etc.nomad_docker_json.text = ''
    plugin "docker" {
        config {
            allow_privileged = true
            volumes {
                # required for bind mounting host directories
                enabled = true
            }
        }
    }
    client {
        cni_path = "${pkgs.cni-plugins}/bin"
    }
  }'';

  services.nomad = {
    enableDocker = true;
    dropPrivileges = false;
    extraPackages = [ pkgs.cni-plugins];
    extraSettingsPaths = [ "/etc/nomad_docker_json" ];

    settings = {
        server = {
            enabled = true;
            bootstrap_expect = 3;
            server_join = {
                retry_join     = [ "192.168.102.100" "192.168.102.101" "192.168.102.102" ];
                retry_max      = 3;
                retry_interval = "15s";
            };
        };
        client = {
            cni_path = pkgs.cni-plugins + "/bin";
            enabled = true;
        };
    };
  };

  services.consul.interface.bind = "enp2s0";
  services.nomad.enable = true;

  networking.firewall.allowedTCPPorts = [ 80 8300 8301 8500 8600 ];
  networking.firewall.allowedTCPPortRanges = [
    { from = 4646; to = 4648; }
    { from = 8080; to = 8081; }
  ];
}
