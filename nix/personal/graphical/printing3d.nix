{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.kp2pml30;
in
lib.mkIf cfg.printing3d {
  users.users.${cfg.username}.packages = with pkgs; [
    # ships Creality K1C profiles and uploads over LAN via the "Creality Print" host type
    orca-slicer
    freecad
  ];
}
