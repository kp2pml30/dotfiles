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
    # and enables DXVK async pipeline compilation. Steam launch options:
    #   game-wrapper %command%
    (writeShellApplication {
      name = "game-wrapper";
      runtimeInputs = [ gamescope ];
      text = ''
        export DXVK_ASYNC=1            # legacy dxvk-async (DXVK < 2.x / async-patched builds)
        export DXVK_GPLASYNCCACHE=1    # modern dxvk-gplasync (DXVK >= 2.x)
        exec gamescope -W ${toString cfg.gayming.width} -H ${toString cfg.gayming.height} -r ${toString cfg.gayming.refreshRate} -f -- "$@"
      '';
    })
  ];
}
