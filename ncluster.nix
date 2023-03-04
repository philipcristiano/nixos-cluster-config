{ config, pkgs, buildGoModule, pkg-config, ... }:

let

nomad_usb_device_plugin = pkgs.buildGoModule {
      src = pkgs.fetchFromGitLab {
          owner = "CarbonCollins";
          repo = "nomad-usb-device-plugin";
          rev = "0.4.0";
          sha256 = "sha256-k5L07CzQkY80kHszCLhqtZ0LfGGuV07LrHjvdgy04bk=";
      };
      vendorSha256 = "sha256-gf2E7DTAGTjoo3nEjcix3qWjHJHudlR7x9XJODvb2sk=";
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
        addresses = {
            http = "0.0.0.0";
        };
        retry_join     = [ "192.168.102.100" "192.168.102.101" "192.168.102.102" ];
        acl  = {
            enabled = false;
            default_policy = "allow";
            enable_token_persistence = true;
        };
        ui_config = {
            enabled = true;
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
          allow_caps = ["audit_write", "chown", "dac_override", "fowner",
          "fsetid", "kill", "mknod", "net_bind_service", "setfcap", "setgid",
          "net_admin",
          "setpcap", "setuid", "sys_chroot"]
      }
  }
  '';
  environment.etc.nomad_extras_json.text = ''
  client {
      cni_path = "${pkgs.cni-plugins}/bin"
  }

  plugin_dir = "${nomad_usb_device_plugin}/bin"

  telemetry {
    publish_allocation_metrics = true
    publish_node_metrics       = true
    prometheus_metrics         = true
  }

  '';
  environment.etc.nomad_usb_json.text = ''
   plugin "usb" {
     config {
       enabled = true

       included_vendor_ids = [0x0658]
       excluded_vendor_ids = []

       included_product_ids = [0x0200]
       excluded_product_ids = []

       fingerprint_period = "1m"
    }
  }
  '';
  services.nomad = {
    enableDocker = true;
    dropPrivileges = false;
    extraPackages = [ pkgs.cni-plugins nomad_usb_device_plugin];
    extraSettingsPaths = [ "/etc/nomad_extras_json" "/etc/nomad_docker_json"  "/etc/nomad_usb_json" ];

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

  networking.firewall.allowedUDPPorts = [ 1680 1700 ];
  networking.firewall.allowedTCPPorts = [ 80 443 1883 8300 8301 8500 8600 ];
  networking.firewall.allowedTCPPortRanges = [
    { from = 6379; to = 6390; }
    { from = 4646; to = 4648; }
    { from = 8080; to = 8081; }
    { from = 8882; to = 8884; }
  ];

}
