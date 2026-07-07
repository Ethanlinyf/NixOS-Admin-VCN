{ config, pkgs, ... }:

let
  vncPort = 5900;
in
{
  # === x11vnc VNC Server for XFCE
  systemd.services.x11vnc = {
    description = "x11vnc VNC Server for XFCE";
    after = [ "lightdm.service" ];
    wants = [ "lightdm.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStartPre = pkgs.writeShellScript "wait-for-lightdm-xauth" ''
        set -e
        for i in $(seq 1 60); do
          if [ -f /var/run/lightdm/root/:0 ]; then
            echo "X authority file ready after $i seconds"
            exit 0
          fi
          sleep 1
        done
        echo "ERROR: Timed out waiting for /var/run/lightdm/root/:0" >&2
        exit 1
      '';
      ExecStart = "${pkgs.x11vnc}/bin/x11vnc -display :0 -auth /var/run/lightdm/root/:0 -forever -shared -rfbauth /root/.vnc/passwd -rfbport ${toString vncPort} -noxdamage -ncache 10 -repeat";
      Restart = "always";
      RestartSec = 10;
      User = "root";
    };
  };

  # Open VNC port and rate limit new connections to slow brute force attacks.
  # Max 4 new connection attempts per minute per source IP.
  networking.firewall.allowedTCPPorts = [ vncPort ];

  networking.firewall.extraCommands = ''
    iptables -I nixos-fw 1 -p tcp --dport ${toString vncPort} -m conntrack --ctstate NEW \
      -m limit --limit 4/minute -j ACCEPT || true
    iptables -I nixos-fw 2 -p tcp --dport ${toString vncPort} -m conntrack --ctstate NEW -j DROP || true
  '';

  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -p tcp --dport ${toString vncPort} -m conntrack --ctstate NEW \
      -m limit --limit 4/minute -j ACCEPT 2>/dev/null || true
    iptables -D nixos-fw -p tcp --dport ${toString vncPort} -m conntrack --ctstate NEW -j DROP 2>/dev/null || true
  '';
}