{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.kp2pml30;
in
lib.mkIf cfg.xserver {
  programs.obs-studio.enable = true;
  programs.obs-studio.enableVirtualCamera = true;

  environment.systemPackages = [ pkgs.v4l-utils ];
}
