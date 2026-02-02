{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix.url = "github:Mic92/sops-nix";
    deploy-rs.url = "github:serokell/deploy-rs";
  };
  outputs = { self, nixpkgs, flake-utils, sops-nix, deploy-rs }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ deploy-rs.overlays.default  ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
        in
        with pkgs;
        {
          devShells.default = mkShell {
            buildInputs = [
                pkgs.sops
                pkgs.age
                pkgs.git
                pkgs.ssh-to-age
                sops-nix.nixosModules.sops
                pkgs.deploy-rs.deploy-rs
            ];
          };
        }
      );
}
