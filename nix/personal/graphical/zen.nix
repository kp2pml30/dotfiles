{
  pkgs,
  lib,
  config,
  inputs,
  rootPath,
  ...
}:
let
  cfg = config.kp2pml30;
in
lib.mkIf cfg.xserver {
  environment.systemPackages = [
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  home-manager.users.${cfg.username} = {
    # zen creates profiles on first run; pin one so user.js has a home
    home.file.".zen/profiles.ini" = {
      source = rootPath + "/home/.zen/profiles.ini";
    };

    home.file.".zen/default/user.js" = {
      source = rootPath + "/home/.zen/default/user.js";
    };
  };
}
