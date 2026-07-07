{ config, pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16.withPackages (ps: with ps; [ pgvector ]);
    settings = {
      shared_preload_libraries = "vector";
    };
    # Listens on 5432; default authentication: peer for local unix sockets, md5 for TCP
    # Add users/databases declaratively via services.postgresql.ensureDatabases / ensureUsers if desired
  };

  networking.firewall.allowedTCPPorts = [ 5432 ];
}