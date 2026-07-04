{
  config,
  lib,
  ...
}:
let
  cfg = config.kp2pml30;
in
lib.mkIf cfg.hardware.audio {
  home-manager.users.${cfg.username}.xdg.desktopEntries = lib.mkIf cfg.xserver {
    pulsemixer = {
      name = "pulsemixer";
      comment = "Audio mixer";
      exec = "kitty -e pulsemixer";
      terminal = false;
      categories = [
        "Utility"
        "AudioVideo"
        "Audio"
        "X-TUI"
      ];
    };
  };
}
