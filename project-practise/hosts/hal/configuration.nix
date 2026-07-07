{ config, pkgs, lib, unstable, ... }:

{
  nixpkgs.hostPlatform = "x86_64-linux";

  imports = [ 
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/nvidia.nix
    ../../modules/qwen3.59b.nix
    ../../modules/node-red.nix
  ];

  environment.systemPackages = with pkgs; [
    google-chrome
  ];
}