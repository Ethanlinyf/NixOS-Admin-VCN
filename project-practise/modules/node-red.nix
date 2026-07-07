{ config, pkgs, ... }:

{
  services.node-red = {
    enable = true;
    openFirewall = true; # opens 1880 for the web UI
    withNpmAndGcc = true;   # ← enables palette manager + npm
    # Web UI on port 1880 (http://<local-ip>:1880)
    # Persistent data in /var/lib/node-red; flows editable via UI
  };
  systemd.services.node-red.path = with pkgs; [
    git
    bash
    gnumake
    python3
    stdenv.cc
  ];
}