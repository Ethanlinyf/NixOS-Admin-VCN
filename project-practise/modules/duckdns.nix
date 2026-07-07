{ config, pkgs, ... }:

{
  # DuckDNS updater
  systemd.services.duckdns-update = {
    description = "Update DuckDNS with local LAN IP";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [ iproute2 curl ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${pkgs.bash}/bin/bash /etc/bitdeploy/modules/duckdns-local-ip-update.sh";
    };
  };

  systemd.timers.duckdns-update = {
    description = "Run DuckDNS local-IP update every 5 minutes";
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };
}