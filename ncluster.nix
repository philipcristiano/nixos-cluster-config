{ config, pkgs, ... }:

{ environment.systemPackages = [ pkgs.consul ];
}
