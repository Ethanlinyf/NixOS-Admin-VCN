{ config, pkgs, lib, unstable, ... }:

{
  nixpkgs.hostPlatform = "x86_64-linux";

  imports = [ 
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/nvidia.nix
    ../../modules/qwen3.59b.nix
    ../../modules/node-red.nix
    ../../modules/mosquitto.nix
    ../../modules/postgresql.nix
    ../../modules/mongodb.nix
    ../../modules/fuxa.nix
  ];

  # host-specific postgresql configuration
  services.postgresql = {
    ensureDatabases = [ "iot_trainerboard" ];
    ensureUsers = [
      {
        name = "node-red";
        # ensureDBOwnership removed to satisfy the NixOS postgresql module assertion
        # (requires a database with the exact same name as the user when ownership is requested).
        # The "node-red" role is still created. Grant it access to iot_trainerboard
        # from your Node-RED flows (you control the data layer).
      }
    ];
  };

  # host-specific mongodb configuration
  services.mongodb = {
    bind_ip = "0.0.0.0";           # so tarscqu.duckdns.org and LAN IP are reachable
    enableAuth = true;             # 25.11 module auto-creates root user on first start
    initialRootPasswordFile = "/etc/nixdeploy/secrets/mongodb-root-password";
  };

  # Idempotent init for sensor data (trainerboard + tempbox demonstrators)
  systemd.services.mongodb.postStart = lib.mkAfter '' 
    if [ -f /etc/nixdeploy/secrets/mongodb-root-password ]; then
      MONGODB_ROOT_PASSWORD=$(cat /etc/nixdeploy/secrets/mongodb-root-password)
      ${pkgs.mongosh}/bin/mongosh --quiet \
        mongodb://127.0.0.1:27017 \
        --username root --password "$MONGODB_ROOT_PASSWORD" --authenticationDatabase admin \
        --eval '
          const dbName = "iot_demonstrator";

          // trainerboard_demonstrator
          const collName1 = "trainerboard_demonstrator";
          const db = db.getSiblingDB(dbName);
          if (!db.getCollectionNames().includes(collName1)) {
            db.createCollection(collName1);
            db[collName1].createIndex({ ts: -1 });
            print("Initialized " + dbName + "." + collName1 + " with ts index");
          } else {
            print(dbName + "." + collName1 + " already exists");
          }

          // tempbox_demonstrator (new)
          const collName2 = "tempbox_demonstrator";
          if (!db.getCollectionNames().includes(collName2)) {
            db.createCollection(collName2);
            db[collName2].createIndex({ ts: -1 });
            print("Initialized " + dbName + "." + collName2 + " with ts index");
          } else {
            print(dbName + "." + collName2 + " already exists");
          }
        '
    else
      echo "WARNING: /etc/nixdeploy/secrets/mongodb-root-password missing – skipping collection init (create it and rebuild)"
    fi
  '';

  environment.systemPackages = with pkgs; [ 
    google-chrome
    mongosh
  ];
}