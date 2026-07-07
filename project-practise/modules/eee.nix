{ config, pkgs, ... }:

{
  # === Disable EEE on enp0s25 (Intel I217-LM) for link stability
  #     (prevents potential power-saving related flaps on this NIC)
  systemd.services.disable-eee-enp0s25 = {
    description = "Disable Energy Efficient Ethernet on enp0s25";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ethtool}/bin/ethtool --set-eee enp0s25 eee off";
      RemainAfterExit = true;
    };
  };
}