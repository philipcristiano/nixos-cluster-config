## Excerpt


services.vault = {
    package = pkgs.vault-bin;
    enable = true;
    tlsCertFile = "/var/lib/vault/certs/vault-cert.pem";
    tlsKeyFile  = "/var/lib/vault/certs/vault-key.pem";
    address = "0.0.0.0:8200";
    listenerExtraConfig = "
tls_client_ca_file = \"/var/lib/vault/certs/ca-cert.pem\"
    ";

    storageBackend = "raft";
    storageConfig = "

orage \"raft\" {

retry_join {
  leader_tls_servername   = \"192.168.102.100\"
  leader_api_addr         = \"https://192.168.102.100:8200\"
  leader_ca_cert_file     = \"/var/lib/vault/certs/ca_cert.pem\"
  leader_client_cert_file = \"/var/lib/vault/certs/vault-cert.pem\"
  leader_client_key_file  = \"/var/lib/vault/certs/vault-key.pem\"
}
retry_join {
  leader_tls_servername   = \"192.168.102.101\"
  leader_api_addr         = \"https://192.168.102.101:8200\"
  leader_ca_cert_file     = \"/var/lib/vault/certs/ca_cert.pem\"
  leader_client_cert_file = \"/var/lib/vault/certs/vault-cert.pem\"
  leader_client_key_file  = \"/var/lib/vault/certs/vault-key.pem\"
}
retry_join {
  leader_tls_servername   = \"192.168.102.101\"
  leader_api_addr         = \"https://192.168.102.101:8200\"
  leader_ca_cert_file     = \"/var/lib/vault/certs/ca_cert.pem\"
  leader_client_cert_file = \"/var/lib/vault/certs/vault-cert.pem\"
  leader_client_key_file  = \"/var/lib/vault/certs/vault-key.pem\"
}

    ";
    extraConfig = "
      ui = true
      cluster_addr = \"https://{{ GetInterfaceIP \\\"enp2s0\\\" }}:8201\"
      api_addr = \"https://{{ GetInterfaceIP \\\"enp2s0\\\" }}:8200\"
      log_level = \"debug\"
    ";
};

networking.firewall.allowedTCPPortRanges = [
  { from = 8200; to = 8201; } # Vault
];

