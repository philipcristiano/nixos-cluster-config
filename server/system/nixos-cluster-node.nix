{ config, options, hostName, pkgs, ... }:

{

  imports =
    [ # Include hardware configuration based on hostname
      (./. + "/${hostName}-hardware.nix")
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = "8192";
  };

  networking.hostName = "${hostName}"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp2s0.useDHCP = true;
  networking.vlans = {
	  vlan110 = { id=110; interface="enp2s0"; };
  };
  networking.interfaces.vlan110.useDHCP = true;
  # networking.interfaces.vlan110.macAddress = "stable";
  networking.timeServers = options.networking.timeServers.default ++ [ "192.168.102.1" ];



  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.philipcristiano = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  nix.settings.trusted-users = [ "root" "philipcristiano" ];
  security.sudo.wheelNeedsPassword = false;


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    podman-tui
    wget
  #   firefox
  ];

  virtualisation.containers.enable = true;
  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      # TODO: Conflicts with docker, so maybe we're not ready yet!
      # dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).

  # https://discourse.nixos.org/t/warning-boot-enablecontainers-virtualisation-containers-unsupported/21249/4
  system.stateVersion = "22.05"; # Did you read the comment?


  system.autoUpgrade.enable = false;
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = "nix-command flakes";
}
