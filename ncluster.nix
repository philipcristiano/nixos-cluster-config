{ config, pkgs, ... }:

{ environment.systemPackages = [ pkgs.consul
                                 pkgs.nomad
                                 pkgs.vault];
}
