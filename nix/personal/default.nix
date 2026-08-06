{
  config,
  pkgs,
  inputs,
  lib,
  ...
}@args:
let
  cfg = config.kp2pml30;
  startsWith = prefix: str: builtins.substring 0 (builtins.stringLength prefix) str == prefix;
in
{
  options.kp2pml30 = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "kp2pml30";
    };
    xserver = lib.mkEnableOption "";
    agent = {
      enable = lib.mkEnableOption "";
      local = lib.mkEnableOption "heavy weight local-only agent features (e.g. Ollama)";
    };
    vscode = lib.mkEnableOption "";
    kitty = lib.mkEnableOption "";
    opera = lib.mkEnableOption "";
    sync-files = {
      enable = lib.mkEnableOption "personal notes and password sync";
      syncthing.devices = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }:
            {
              options = {
                id = lib.mkOption {
                  type = lib.types.str;
                  description = "Syncthing device ID.";
                };
                addresses = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ "tcp://${name}.ts.kp2pml30.moe:22000" ];
                  description = "Syncthing device addresses. Defaults to this host name under Headscale MagicDNS.";
                };
              };
            }
          )
        );
        default = { };
        description = "Known tailnet Syncthing peers. Leave empty until device IDs are known.";
      };
    };
    gayming = {
      enable = lib.mkEnableOption "gaming setup (Steam, gamescope, game-wrapper)";
      width = lib.mkOption {
        type = lib.types.int;
        description = "gamescope output width used by game-wrapper";
      };
      height = lib.mkOption {
        type = lib.types.int;
        description = "gamescope output height used by game-wrapper";
      };
      refreshRate = lib.mkOption {
        type = lib.types.int;
        description = "gamescope output refresh rate (Hz) used by game-wrapper";
      };
    };
    messengers = {
      personal = lib.mkEnableOption "";
      work = lib.mkEnableOption "";
    };
    damn-rust = {
      enable = lib.mkEnableOption "file-backed btrfs store for rust build directories";
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/damn-rust";
        description = "Where the store is mounted.";
      };
      image = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/damn-rust/store.img";
        description = "Sparse file backing the store.";
      };
      size = lib.mkOption {
        type = lib.types.str;
        default = "128G";
        description = "Apparent size of the sparse image; it only ever allocates what is written.";
      };
    };
  };

  imports = [
    ./graphical
    ./home.nix
    ./git.nix
    ./user.nix
    ./neovim.nix
    ./tui.nix
    ./agent
    ./wireless.nix
    ./audio.nix
    ./sync-files.nix
    ./damn-rust.nix
  ];

  config = {

    kp2pml30.machine-kind = "personal";
    kp2pml30.oom-killer = true;

    boot.supportedFilesystems = [ "exfat" ] ++ lib.optional cfg.gayming.enable "ntfs";
    boot.loader.timeout = 30;

    documentation.doc.enable = false;
    # [ "zfs" ]
    # boot.zfs.forceImportRoot = false;

    services.logind.settings.Login = {
      HandlePowerKey = "poweroff";
      HandleLidSwitch = "hibernate";
    };

    services.pcscd = {
      enable = true;
    };

    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    i18n.supportedLocales = [
      "C.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
      "ru_RU.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
    ];

    programs = {
      fish.enable = true;
    };

    environment.systemPackages = with pkgs; [
      fish
      fishPlugins.grc
      fishPlugins.bass
      nushell
      carapace

      python312 # needed for bass
      grc
    ];

    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.any (x: startsWith x (pkgs.lib.getName pkg)) [
        "vscode"
        "steam"
        "nvidia"
      ]
      || builtins.elem (pkgs.lib.getName pkg) [
        "anytype-heart"
        "opera"
        "discord"
        "slack"
        "anytype"
        "claude-code"
        "obsidian"
      ];
  };
}
