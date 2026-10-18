{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.kp2pml30;
in
{
  imports = [
    ./x.nix
    ./kitty.nix
    ./vscode.nix
    ./firefox.nix
    ./zen.nix
    ./virtual-cam.nix

    ./gayming.nix
    ./guitar.nix
    ./printing3d.nix

    ./messengers.nix
    ./messengers-work.nix
  ];

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.kitty -> cfg.xserver;
          message = "kp2pml30.kitty requires kp2pml30.xserver";
        }
        {
          assertion = cfg.vscode -> cfg.xserver;
          message = "kp2pml30.vscode requires kp2pml30.xserver";
        }
        {
          assertion = cfg.opera -> cfg.xserver;
          message = "kp2pml30.opera requires kp2pml30.xserver";
        }
        {
          assertion = cfg.gayming.enable -> cfg.xserver;
          message = "kp2pml30.gayming requires kp2pml30.xserver";
        }
        {
          assertion = cfg.guitar -> cfg.xserver;
          message = "kp2pml30.guitar requires kp2pml30.xserver";
        }
        {
          assertion = cfg.guitar -> cfg.hardware.audio;
          message = "kp2pml30.guitar requires kp2pml30.hardware.audio";
        }
        {
          assertion = cfg.printing3d -> cfg.xserver;
          message = "kp2pml30.printing3d requires kp2pml30.xserver";
        }
        {
          assertion = cfg.messengers.personal -> cfg.xserver;
          message = "kp2pml30.messengers.personal requires kp2pml30.xserver";
        }
        {
          assertion = cfg.messengers.work -> cfg.xserver;
          message = "kp2pml30.messengers.work requires kp2pml30.xserver";
        }
      ];
    }
    (lib.mkIf cfg.xserver {
      xdg.portal = {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.common.default = "*";
      };
      services.flatpak.enable = true;
      systemd.services.flatpak-repo = {
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.flatpak ];
        script = ''
          flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        '';
      };

      systemd.services.flatpak-update = {
        path = [ pkgs.flatpak ];
        serviceConfig.Type = "oneshot";
        script = ''
          flatpak update --noninteractive --assumeyes
        '';
      };
      systemd.timers.flatpak-update = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };

      environment.systemPackages = with pkgs; [
        #anytype
        flatpak
        gnome-software
        feh
        vlc
      ];

      fonts.enableDefaultPackages = true;
      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-sans

        fira-code
        fira-code-symbols

        nerd-fonts.fira-code
      ];
    })
  ];
}
