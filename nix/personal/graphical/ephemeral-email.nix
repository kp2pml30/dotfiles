{
  pkgs,
  lib,
  config,
  data,
  ...
}:
let
  cfg = config.kp2pml30;
  mail = import ../../server/mail/common.nix data;
  inherit (data.mail) domain reserved;
in
lib.mkIf cfg.xserver {
  users.users.${cfg.username}.packages = [
    (pkgs.writers.writePython3Bin "email" {
      doCheck = false;
      makeWrapperArgs = lib.concatLists (
        lib.mapAttrsToList
          (name: value: [
            "--set"
            "EMAIL_${name}"
            value
          ])
          {
            ADDRESS = "${reserved.owner}@${domain}";
            NAME = reserved.owner;
            HOST = mail.fqdn;
            SWAP = lib.boolToString (lib.all (d: d.randomEncryption.enable) config.swapDevices);
            THUNDERBIRD = lib.getExe pkgs.thunderbird;
            BWRAP = "${pkgs.bubblewrap}/bin/bwrap";
            SYSTEMD_RUN = "${config.systemd.package}/bin/systemd-run";
            SYSTEMD_INHIBIT = "${config.systemd.package}/bin/systemd-inhibit";
          }
      );
    } (builtins.readFile ./ephemeral-email.py))
  ];
}
