{
  inputs = {
    libedgetpu.url = "github:jhvst/nix-flake-edgetpu";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    deploy-rs.url = "github:serokell/deploy-rs";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, libedgetpu, deploy-rs, sops-nix }: {
    packages."x86_64-linux".libedgetpu = libedgetpu;
    nixosConfigurations.nixos00 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { hostName = "nixos00"; };
      modules = [ sops-nix.nixosModules.sops ./system/nixos-cluster-node.nix ./ncluster.nix ./lab/single.nix ];
    };
    nixosConfigurations.nixos01 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { hostName = "nixos01"; };
      modules = [ sops-nix.nixosModules.sops ./system/nixos-cluster-node.nix ./ncluster.nix ];
    };
    nixosConfigurations.nixos02 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { hostName = "nixos02"; };
      modules = [ sops-nix.nixosModules.sops ./system/nixos-cluster-node.nix ./ncluster.nix ];
    };
  description = "Deploy GNU hello to localhost";

  inputs.deploy-rs.url = "github:serokell/deploy-rs";

    deploy.nodes.nixos00 = {
      hostname = "192.168.102.100";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.nixos00;
      };
    };
    deploy.nodes.nixos01 = {
      hostname = "192.168.102.101";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.nixos01;
      };
    };
    deploy.nodes.nixos02 = {
      hostname = "192.168.102.102";
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.nixos02;
      };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
