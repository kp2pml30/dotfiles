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

  shortcutOverrides = rootPath + "/home/.zen/keyboard-shortcut-overrides.json";
  spliceProgram = rootPath + "/home/.zen/splice-keyboard-shortcuts.jq";

  # zen owns zen-keyboard-shortcuts.json: it rewrites the whole list on startup, on
  # migrations and on every UI edit, so the overrides are spliced in on activation
  # rather than symlinked. Everything zen wrote that we do not override is left alone.
  spliceShortcuts = pkgs.writeShellScript "zen-splice-keyboard-shortcuts" ''
    set -eu
    file="$HOME/.zen/default/zen-keyboard-shortcuts.json"
    [ -f "$file" ] || exit 0
    trap 'rm -f "$file.tmp"' EXIT
    ${pkgs.jq}/bin/jq --slurpfile ov ${shortcutOverrides} -f ${spliceProgram} "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
  '';
in
lib.mkIf cfg.xserver {
  environment.systemPackages = [
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  home-manager.users.${cfg.username} =
    { lib, ... }:
    {
      # zen creates profiles on first run; pin one so user.js has a home
      home.file.".zen/profiles.ini" = {
        source = rootPath + "/home/.zen/profiles.ini";
      };

      home.file.".zen/default/user.js" = {
        source = rootPath + "/home/.zen/default/user.js";
      };

      home.file.".zen/default/chrome/userChrome.css" = {
        source = rootPath + "/home/.zen/default/chrome/userChrome.css";
      };

      home.sessionVariables.BROWSER = "zen";

      xdg.mimeApps.defaultApplications = builtins.listToAttrs (
        map
          (t: {
            name = t;
            value = [ "zen.desktop" ];
          })
          [
            "x-scheme-handler/http"
            "x-scheme-handler/https"
            "x-scheme-handler/about"
            "x-scheme-handler/unknown"
            "application/xhtml+xml"
          ]
      );

      home.activation.zenKeyboardShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${spliceShortcuts}
      '';
    };
}
