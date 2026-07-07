{ config, pkgs, ... }:
{
  # FUXA web-based SCADA/HMI + IoT dashboards (https://github.com/frangoteam/FUXA)
  # Deployed via official container image to stay as close as possible to the
  # upstream Docker / compose.yml model while remaining fully declarative.
  #
  # Web UI: http://<host>:1881  (use Chrome)
  # Data layout mirrors upstream: _appdata (projects), _db (historian/DAQ),
  # _logs, _images under the server/ tree inside the container.
  #
  # Integrates naturally with existing tars stack (MQTT, Node-RED, Postgres, Mongo).
  # Node-RED users can later install node-red-contrib-fuxa via the palette for
  # deeper integration if desired.

  virtualisation.podman.enable = true;

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      fuxa = {
        image = "frangoteam/fuxa:latest";  # Pin to e.g. "frangoteam/fuxa:1.3.2" for reproducibility
        ports = [ "1881:1881" ];
        volumes = [
          "/var/lib/fuxa/appdata:/usr/src/app/FUXA/server/_appdata"
          "/var/lib/fuxa/db:/usr/src/app/FUXA/server/_db"
          "/var/lib/fuxa/logs:/usr/src/app/FUXA/server/_logs"
          "/var/lib/fuxa/images:/usr/src/app/FUXA/server/_images"
        ];
        autoStart = true;
      };
    };
  };

  # Ensure persistent directories exist early (NixOS tmpfiles, before container unit).
  # Matches the four volume mounts used in FUXA's official compose.yml and Dockerfile.
  systemd.tmpfiles.rules = [
    "d /var/lib/fuxa/appdata 0755 root root - -"
    "d /var/lib/fuxa/db 0755 root root - -"
    "d /var/lib/fuxa/logs 0755 root root - -"
    "d /var/lib/fuxa/images 0755 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [ 1881 ];
}