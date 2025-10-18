{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.kp2pml30.server;
  ports = config.kp2pml30.server.ports;
in lib.mkIf cfg.xray {
  services.xray = {
    enable = true;
    settingsFile = "/run/secrets/xray-config.json";
  };

  # Ensure xray can read the certificates
  users.users.xray.extraGroups = [ "nginx" ];

  # Ensure the xray service starts after ACME certificates are available
  systemd.services.xray.after = [ "acme-${cfg.hostname}.service" ];
  systemd.services.xray.wants = [ "acme-${cfg.hostname}.service" ];
}