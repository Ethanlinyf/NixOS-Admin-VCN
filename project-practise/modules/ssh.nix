{ config, pkgs, ... }:

{
  # === SSH
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false; # ssh public/private key login only
      PermitRootLogin = "no";
    };
  };

  users.users.pi.openssh.authorizedKeys.keyFiles = [
    "/etc/nixdeploy/secrets/ssh-authorized-key"
  ];
}