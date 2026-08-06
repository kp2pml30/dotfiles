{
  config,
  pkgs,
  inputs,
  lib,
  ...
}@args:
let
  cfg = config.kp2pml30;
in
{
  config = {
    nixpkgs.overlays = lib.optionals cfg.agent.enable [
      inputs.claude-code.overlays.default
      inputs.codex-cli.overlays.default
    ];
    programs = {
      tmux.enable = true;
      htop.enable = true;
    };

    environment.systemPackages = with pkgs; [
      joshuto
      ncdu
      timewarrior
      p7zip
      lazydocker
      gh
    ];

    home-manager.users.${cfg.username}.xdg.desktopEntries = lib.mkIf cfg.xserver {
      htop = {
        name = "htop";
        comment = "Process monitor";
        exec = "kitty -e htop";
        terminal = false;
        categories = [
          "Utility"
          "System"
          "Monitor"
          "X-TUI"
        ];
      };
      ncdu = {
        name = "ncdu";
        comment = "Disk usage analyzer";
        exec = "kitty -e ncdu";
        terminal = false;
        categories = [
          "Utility"
          "System"
          "X-TUI"
        ];
      };
      lazydocker = {
        name = "lazydocker";
        comment = "Docker TUI";
        exec = "kitty -e lazydocker";
        terminal = false;
        categories = [
          "Utility"
          "Development"
          "X-TUI"
        ];
      };
    };
  };
}
