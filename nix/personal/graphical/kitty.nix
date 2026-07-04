{
  pkgs,
  lib,
  rootPath,
  config,
  inputs,
  ...
}:
let
  cfg = config.kp2pml30;
in
lib.mkIf cfg.kitty {
  nixpkgs.overlays = [ inputs.herdr.overlays.default ];

  home-manager.users.${cfg.username} = {
    programs.kitty = {
      enable = true;
      extraConfig = builtins.readFile (rootPath + "/home/.config/kitty/kitty.conf");
    };

    # herdr: terminal multiplexer for running coding agents side by side
    home.packages = [ pkgs.herdr ];
  };
}
