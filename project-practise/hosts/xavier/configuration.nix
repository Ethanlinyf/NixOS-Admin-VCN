# Ignored by non-nixos, here as a placeholder
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#

{ config, pkgs, lib, unstable, ... }:

{
  nixpkgs.hostPlatform = "aarch64-linux";

  # firefox won't build on the jetson agx xavier
  #programs.firefox.enable = lib.mkForce false;

  imports = [ 
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/nvidia_xavier.nix
    ../../modules/qwen3.59b.nix
    ../../modules/node-red.nix
    (builtins.getFlake "github:anduril/jetpack-nixos").nixosModules.default
  ];

  # Fix for libsecret test failure on Xavier
  nixpkgs.overlays = [
    (final: prev: {
      libsecret = prev.libsecret.overrideAttrs (old: {
        doCheck = false;
      });
    })
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;

  # graphics
  boot.kernelParams = [
    "fbcon=map:2"
    "console=tty0"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
  ];
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia-jetpack.modesetting.enable = true;

 services.xserver.desktopManager.xfce.enable = true;
 services.xserver.displayManager.lightdm.enable = true;

  users.users.pi = {
    isNormalUser = true;
    description = "pi";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };
}
