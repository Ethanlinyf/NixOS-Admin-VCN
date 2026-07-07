# unused for the jetpack installation,
# retained for any possible future pure nixos deployment

{ config, pkgs, ... }: {
  services.xserver.videoDrivers = [ "nvidia" ];

#  hardware.graphics = {
#    enable = true;
#    enable32Bit = true;
#  };

#  hardware.nvidia = {
#    modesetting.enable = true;
#    open = true;
#    nvidiaSettings = true;
#    package = config.boot.kernelPackages.nvidiaPackages.stable;
#  };

  # remedy xfce4 terminal glitching issues
#  services.xserver.desktopManager.xfce.extraSessionCommands = ''
#    xfconf-query -c xfwm4 -p /general/use_compositing -t bool -s false || true
#  '';

  hardware.nvidia-jetpack.enable = true;
  hardware.nvidia-jetpack.som = "xavier-agx";
  hardware.nvidia-jetpack.carrierBoard = "devkit";
  hardware.nvidia-jetpack.majorVersion = "5";

#  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
#  boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
}
