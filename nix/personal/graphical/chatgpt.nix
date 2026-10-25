{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kp2pml30;
in
lib.mkIf (cfg.agent.chatgpt && cfg.xserver) {
  environment.systemPackages = [ (pkgs.callPackage ./chatgpt { }) ];

  home-manager.users.${cfg.username}.xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/codex" = [ "chatgpt.desktop" ];
  };
}
