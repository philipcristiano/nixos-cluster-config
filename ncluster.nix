{ config, pkgs, buildGoModule, pkg-config, ... }:

let

nomad_usb_device_plugin = pkgs.buildGoModule {
      src = pkgs.fetchFromGitLab {
          owner = "CarbonCollins";
          repo = "nomad-usb-device-plugin";
          rev = "0.2.0";
          sha256 = "sha256:08fjxvxd9zlibk9nvj4skh99k7mklndflxbdy2xjhsxcn32s0v1w";
      };
      vendorSha256 = "sha256:1l8ph420974n3rh4cfy1q5gz140ynh96il8a8klxw81jnfiai008";
      name = "nomad-usb-device-plugin";
      nativeBuildInputs = [ pkgs.pkg-config ];
      buildInputs = [ pkgs.libusb ];
    };

in

{ environment.systemPackages = [ pkgs.cni-plugins
                                 pkgs.nfs-utils
                                 pkgs.consul
                                 pkgs.nomad
                                 nomad_usb_device_plugin
                                 pkgs.vault];
  services.consul.enable = true;
  services.consul.webUi = true;
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

  services.rpcbind.enable = true;

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
  '';

  services.nomad = {
    enableDocker = true;
    dropPrivileges = false;
    extraPackages = [ pkgs.cni-plugins ];
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
