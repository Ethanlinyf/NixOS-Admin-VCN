{ config, pkgs, ... }:

{
  services.mosquitto = {
    enable = true;

    listeners = [{
      port = 1883;
      address = "0.0.0.0";
      users = {
        admin = {
          passwordFile = "/etc/nixdeploy/secrets/mosquitto-admin-passwd";
          acl = [ "readwrite #" ];
        };
      };
    }];
  };

  networking.firewall.allowedTCPPorts = [ 1883 ];

  environment.systemPackages = with pkgs; [ 
    mosquitto  # CLI clients: mosquitto_pub, mosquitto_sub
  ];
}