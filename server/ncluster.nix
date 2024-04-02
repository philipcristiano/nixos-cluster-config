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
                                 pkgs.gasket # libedgetpu driver
                                 pkgs.nomad_1_4
                                 pkgs.libusb
                                 nomad_usb_device_plugin
                                 pkgs.vault
                                 pkgs.vault-bin];


  boot.extraModulePackages = [ (pkgs.gasket.override { kernel = config.boot.kernelPackages.kernel; }) ];

  # boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

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

  environment.etc.nomad_vault_json.text = ''
vault {
  enabled     = true
  ca_path     = "/var/lib/vault/ca/"
  cert_file   = "/var/lib/vault/certs/vault-cert.pem"
  key_file    = "/var/lib/vault/certs/vault-key.pem"

  address     = "https://vault.home.cristiano.cloud:8200"

  # Embedding the token in the configuration is discouraged. Instead users
  # should set the VAULT_TOKEN environment variable when starting the Nomad
  # agent
  token       = "hvs.CAESIHzUgT2NTrWKbUgdXg9CJ_-414_uBTWWU3Ge61YSCeZrGh4KHGh2cy4xVnM4MzJEMFhoZFZrcnhJMm9OQlRZeWg"

  # Setting the create_from_role option causes Nomad to create tokens for tasks
  # via the provided role. This allows the role to manage what policies are
  # allowed and disallowed for use by tasks.
  create_from_role = "nomad-cluster"
} '';
  environment.etc.nomad_docker_json.text = ''
  plugin "docker" {
      config {
          allow_privileged = true
          volumes {
              # required for bind mounting host directories
              enabled = true
          }
          gc = {
            image_delay = "24h"
          }
          allow_caps = [
            "audit_write",
            "chown",
            "dac_override",
            "fowner",
            "fsetid",
            "kill",
            "mknod",
            "net_admin",
            "net_bind_service",
            "net_raw",
            "setfcap",
            "setgid",
            "setpcap",
            "setuid",
            "sys_chroot"
         ]
      }
  }
  '';
  environment.etc.nomad_extras_json.text = ''
  client {
      cni_path = "${pkgs.cni-plugins}/bin"
      cni_config_dir = "/etc/cni/config"
      host_network "services" {
        cidr = "192.168.110.0/24"
        reserved_ports = ""
      }

      host_volume "minio" {
        path      = "/mnt/data/minio"
        read_only = false
      }

      host_volume "hostfs" {
        path      = "/"
        read_only = true
      }
  }

  server {
    default_scheduler_config {
      scheduler_algorithm = "spread"
      memory_oversubscription_enabled = true

    }
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

       included_vendor_ids = []
       excluded_vendor_ids = []

       included_product_ids = []
       excluded_product_ids = []

       fingerprint_period = "1m"
    }
  }
  '';
  systemd.tmpfiles.rules = [
    "d /opt/minio - - - - "
  ];

  services.nomad = {
    enableDocker = true;
    dropPrivileges = false;
    extraPackages = [ pkgs.cni-plugins nomad_usb_device_plugin];
    extraSettingsPaths = [ "/etc/nomad_extras_json" "/etc/nomad_docker_json"  "/etc/nomad_usb_json" "/etc/nomad_vault_json" ];

    settings = {
        server = {
            enabled = true;
            bootstrap_expect = 3;
            server_join = {
                retry_max      = 10;
                retry_interval = "30s";
            };
        };
        client = {
            cni_config_dir = "/etc/cni/config";
            cni_path = pkgs.cni-plugins + "/bin";
            enabled = true;
        };
    };
  };

  services.consul.interface.bind = "enp2s0";
  services.nomad = {
    enable = true;
    package = pkgs.nomad_1_4;
  };

  # https://github.com/NixOS/nixpkgs/issues/147415
  # systemd.services.cni-dhcp = {
  #   description = "CNI DHCP Daemon";
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStartPre = "${pkgs.coreutils.out}/bin/rm -f /run/cni/dhcp.sock";
  #     ExecStart = "${pkgs.cni-plugins.out}/bin/dhcp daemon";
  #     ExecStop = "${pkgs.coreutils.out}/bin/rm -f /run/cni/dhcp.sock";
  #     Restart = "on-failure";
  #   };
  #   wantedBy = [ "default.target" ];
  # };

  # networking.firewall.enable = false;
  services.vault = {
      package = pkgs.vault-bin;
      enable = true;
      tlsCertFile = "/var/lib/vault/certs/vault-cert.pem";
      tlsKeyFile  = "/var/lib/vault/certs/vault-key.pem";
      address = "0.0.0.0:8200";
      listenerExtraConfig = "
  tls_client_ca_file = \"/var/lib/vault/ca/ca-cert.pem\"
      ";

      storageBackend = "raft";
      storageConfig = "

storage \"raft\" {

  retry_join {
    leader_tls_servername   = \"192.168.102.100\"
    leader_api_addr         = \"https://192.168.102.100:8200\"
    leader_ca_cert_file     = \"/var/lib/vault/ca/ca_cert.pem\"
    leader_client_cert_file = \"/var/lib/vault/certs/vault-cert.pem\"
    leader_client_key_file  = \"/var/lib/vault/certs/vault-key.pem\"
  }
  retry_join {
    leader_tls_servername   = \"192.168.102.101\"
    leader_api_addr         = \"https://192.168.102.101:8200\"
    leader_ca_cert_file     = \"/var/lib/vault/ca/ca_cert.pem\"
    leader_client_cert_file = \"/var/lib/vault/certs/vault-cert.pem\"
    leader_client_key_file  = \"/var/lib/vault/certs/vault-key.pem\"
  }
  retry_join {
    leader_tls_servername   = \"192.168.102.102\"
    leader_api_addr         = \"https://192.168.102.102:8200\"
    leader_ca_cert_file     = \"/var/lib/vault/ca/ca_cert.pem\"
    leader_client_cert_file = \"/var/lib/vault/certs/vault-cert.pem\"
    leader_client_key_file  = \"/var/lib/vault/certs/vault-key.pem\"
  }
}
      ";
      extraConfig = "
        ui = true
        cluster_addr = \"https://{{ GetInterfaceIP \\\"enp2s0\\\" }}:8201\"
        api_addr = \"https://{{ GetInterfaceIP \\\"enp2s0\\\" }}:8200\"
        log_level = \"debug\"

        service_registration \"consul\" {
            address      = \"http://127.0.0.1:8500\"
            service_tags =
                \"traefik.enable=true,traefik.http.routers.vault.tls=true,traefik.http.routers.vault.tls.certresolver=home,traefik.http.services.vault.loadbalancer.server.scheme=https\"
        }
      ";
  };


  networking.firewall.allowedUDPPorts = [ 53 1514 1680 1700 1812 1813 8301];
  networking.firewall.allowedTCPPorts = [ 53 80 443 1883 3080 3443 3636 8300 8301 8500 8554 8600 9000 9090 9735 ];
  networking.firewall.allowedTCPPortRanges = [
    { from = 5433; to = 5500; } # Static port range for Traefik services
    { from = 5501; to = 5510; } # Static port range for Nomad tasks
    { from = 6379; to = 6390; }
    { from = 4646; to = 4648; }
    { from = 8080; to = 8089; }
    { from = 8200; to = 8201; } # Vault
    { from = 8882; to = 8884; }
  ];

}
