{
  pkgs,
  lib,
  rootPath,
  config,
  data,
  ...
}:
let
  cfg = config.kp2pml30;
in
lib.mkIf cfg.gayming.enable {
  assertions = [
    {
      assertion = cfg.gayming.width > 0;
      message = "kp2pml30.gayming.width must be positive (got ${toString cfg.gayming.width})";
    }
    {
      assertion = cfg.gayming.height > 0;
      message = "kp2pml30.gayming.height must be positive (got ${toString cfg.gayming.height})";
    }
    {
      assertion = cfg.gayming.refreshRate > 0;
      message = "kp2pml30.gayming.refreshRate must be positive (got ${toString cfg.gayming.refreshRate})";
    }
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = true;
  };

  programs.gamescope.enable = true;

  hardware.steam-hardware.enable = true;

  users.groups.steam-input.gid = data.gids.steam-input;
  users.users.${cfg.username}.extraGroups = [ "steam-input" ];

  # Switch 2 Pro Controller (057e:2069) — grant Steam uaccess so it can
  # open the hidraw directly. Tracks ValveSoftware/steam-for-linux#12585.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2069", MODE="0660", GROUP="steam-input", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2069", MODE="0660", GROUP="steam-input", TAG+="uaccess"
  '';

  # boot.kernelModules = [ "hid_nintendo" ];
  # disabled: hid-nintendo doesn't support Switch 2 Pro Controller (057e:2069);
  # probe fails with -110 (ETIMEDOUT) and no hidraw fallback is created,
  # so Steam can't see the controller. Leave it on hid-generic + Steam Beta.

  environment.systemPackages = with pkgs; [
    prismlauncher

    # Wraps a game in gamescope (nested compositor, so it can't stall picom)
    # and enables DXVK async pipeline compilation by default. Steam launch options:
    #   game-wrapper %command%
    #   game-wrapper --async=false %command%
    (symlinkJoin {
      name = "game-wrapper";
      paths = [
        (writers.writePython3Bin "game-wrapper" { doCheck = false; } (builtins.readFile ./game-wrapper.py))
      ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/game-wrapper \
          --set GAME_WRAPPER_GAMESCOPE ${lib.getExe gamescope} \
          --set GAME_WRAPPER_WIDTH ${toString cfg.gayming.width} \
          --set GAME_WRAPPER_HEIGHT ${toString cfg.gayming.height} \
          --set GAME_WRAPPER_REFRESH_RATE ${toString cfg.gayming.refreshRate}
      '';
    })
  ];
}
