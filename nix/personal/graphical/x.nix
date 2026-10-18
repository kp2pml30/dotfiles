{
  pkgs,
  config,
  lib,
  rootPath,
  linkTree,
  ...
}:
let
  cfg = config.kp2pml30;
  luaStr = s: "\"" + builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s + "\"";
  tuiEntries = lib.filterAttrs (
    _: e: builtins.elem "X-TUI" (e.categories or [ ])
  ) config.home-manager.users.${cfg.username}.xdg.desktopEntries;
  tuiMenuLua = ''
    -- Generated from xdg.desktopEntries tagged with X-TUI
    return {
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (_: e: "\t{ ${luaStr e.name}, ${luaStr e.exec} },") tuiEntries
    )}
    }
  '';
  inputMethodCycle = pkgs.writeShellApplication {
    name = "input-method-cycle";
    runtimeInputs = [
      config.i18n.inputMethod.package
      pkgs.coreutils
      pkgs.setxkbmap
      pkgs.util-linux
    ];
    text = ''
      action="''${1:-}"
      case $action in
        next) step=1 ;;
        previous) step=-1 ;;
        sync) step=0 ;;
        *) echo "usage: input-method-cycle next|previous|sync" >&2; exit 2 ;;
      esac

      lock_dir="''${XDG_RUNTIME_DIR:-/tmp}"
      exec 9>"$lock_dir/input-method-cycle-$USER.lock"
      flock 9

      session="''${XDG_SESSION_ID:-''${DISPLAY:-display}}"
      state_file="$lock_dir/input-method-cycle-$USER-$session.state"
      pending_file="$lock_dir/input-method-cycle-$USER-$session.pending"

      fcitx_state() {
        fcitx5-remote 2>/dev/null || echo 0
      }

      sync_pending() {
        [[ -r $pending_file ]] || return 0
        for ((attempt = 0; attempt < 20; attempt++)); do
          state=$(fcitx_state)
          if [[ $state == 2 && $(fcitx5-remote -n) == mozc ]]; then
            rm -f "$pending_file"
            return 0
          fi
          if [[ $state == 1 ]]; then
            fcitx5-remote -s mozc
            fcitx5-remote -o
          fi
          sleep 0.05
        done
      }

      if [[ $action == sync ]]; then
        sync_pending
        exit 0
      fi

      state=$(fcitx_state)
      current=0
      if [[ -r $pending_file ]]; then
        current=2
      elif [[ $state == 2 && $(fcitx5-remote -n) == mozc ]]; then
        current=2
      elif [[ $state == 0 && -r $state_file ]]; then
        read -r current < "$state_file"
        [[ $current =~ ^[0-2]$ ]] || current=0
      else
        while read -r field value; do
          if [[ $field == layout: ]]; then
            [[ $value == ru ]] && current=1
            break
          fi
        done < <(setxkbmap -query)
      fi

      target=$(((current + step + 3) % 3))
      case $target in
        0)
          fcitx5-remote -c >/dev/null 2>&1 || true
          setxkbmap -layout us
          echo 0 > "$state_file"
          rm -f "$pending_file"
          ;;
        1)
          fcitx5-remote -c >/dev/null 2>&1 || true
          setxkbmap -layout ru
          echo 1 > "$state_file"
          rm -f "$pending_file"
          ;;
        2)
          if ! fcitx5-remote -n >/dev/null 2>&1; then
            fcitx5 -d
            for ((attempt = 0; attempt < 20; attempt++)); do
              fcitx5-remote -n >/dev/null 2>&1 && break
              sleep 0.05
            done
          fi
          fcitx5-remote -n >/dev/null 2>&1 || exit 1
          setxkbmap -layout us
          fcitx5-remote -s mozc
          fcitx5-remote -o
          echo 2 > "$state_file"
          if [[ $(fcitx_state) == 2 ]]; then
            rm -f "$pending_file"
          else
            : > "$pending_file"
            sync_pending
          fi
          ;;
      esac
    '';
  };
in
lib.mkIf cfg.xserver {
  # Workaround for https://github.com/NixOS/nixpkgs/issues/523345
  # (lgi's ffi.load_enum breaks on GLib >= 2.87). Nixpkgs already applies
  # a partial fix; this adds the missing n_values / ipairs hunk.
  nixpkgs.overlays = [
    (final: prev: {
    })
  ];

  services.displayManager.ly.enable = true;
  services.libinput.enable = true;
  services.xserver = {
    enable = true;
    displayManager.startx.enable = true;
    xkb.layout = "us";
    windowManager.awesome = {
      enable = true;
      luaModules = with pkgs.luaPackages; [
        luarocks
        luadbi-mysql
      ];
    };
    excludePackages = lib.optionals (!cfg.kitty) [
      pkgs.xterm
    ];
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = [ pkgs.fcitx5-mozc ];
      ignoreUserConfig = true;
      settings = {
        globalOptions = {
          "Hotkey/TriggerKeys" = { };
          "Hotkey/AltTriggerKeys" = { };
          "Hotkey/ActivateKeys" = { };
          "Hotkey/DeactivateKeys" = { };
          "Hotkey/EnumerateForwardKeys" = { };
          "Hotkey/EnumerateBackwardKeys" = { };
          "Hotkey/EnumerateGroupForwardKeys" = { };
          "Hotkey/EnumerateGroupBackwardKeys" = { };
          Behavior.ShareInputState = "All";
          "Behavior/DisabledAddons"."0" = "notificationitem";
        };
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "keyboard-us";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "mozc";
            Layout = "us";
          };
          GroupOrder."0" = "Default";
        };
      };
    };
  };

  environment.variables.GLFW_IM_MODULE = "ibus";

  environment.systemPackages = with pkgs; [
    xclip
    brightnessctl
    arandr
    libnotify
    xfce4-screenshooter
  ];

  services.picom = {
    enable = true;
    vSync = true;
    backend = "glx";
  };

  programs.dconf.enable = true;

  users.users.${cfg.username} = {
    packages = with pkgs; [
      inputMethodCycle
      rofimoji
    ];
  };

  home-manager.users.${cfg.username} = {
    programs.rofi = {
      enable = true;
      theme = "simple-tokyonight";
      settings.location = 0; # center
    };
    home.file = linkTree ".config/awesome" (rootPath + "/home/.config/awesome") // {
      ".config/rofi/simple-tokyonight.rasi" = {
        source = rootPath + "/home/.config/rofi/simple-tokyonight.rasi";
      };
      ".config/awesome/tui-menu.lua".text = tuiMenuLua;
      ".config/awesome/deficient" = {
        source = builtins.fetchGit {
          url = "https://github.com/deficient/deficient.git";
          rev = "22ad2bea198f0c231afac0b7197d9b4eb6d80da3";
        };
        recursive = true;
      };
    };
  };
}
