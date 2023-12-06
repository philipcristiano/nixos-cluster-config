{
  inputs = {
    libedgetpu.url = "github:jhvst/nix-flake-edgetpu";
  };

  outputs = { self, nixpkgs, libedgetpu }: {
    packages."x86_64-linux".libedgetpu = libedgetpu;
    nixosConfigurations.nixos00 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ./ncluster.nix ];
    };
    nixosConfigurations.nixos01 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ./ncluster.nix ];
    };
    nixosConfigurations.nixos02 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ./ncluster.nix ];
    };
  };
}
