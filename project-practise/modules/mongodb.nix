{ config, pkgs, ... }:

{
  services.mongodb = {
    enable = true;
    package = pkgs.mongodb;   # explicit pin (matches postgresql.nix style; currently resolves to 7.0.x)
    # Default data directory: /var/lib/mongodb
    # Binds to 127.0.0.1:27017 by default (local only)
  };

  networking.firewall.allowedTCPPorts = [ 27017 ];  
}