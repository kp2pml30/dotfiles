{
  config,
  lib,
  ...
}:
let
  cfg = config.kp2pml30;
  # matched against /proc/comm, which is truncated to 15 chars, and anchored below
  prefer-compiler = "cc1.*|gcc|clang|cargo|rust.*|ghc|go|zig|lto.*";
  prefer-linker = ''ld|ld\..*|lld|mold|gold'';
  prefer-lsp = "clangd|ccls|gopls|.*-language-serve|.*-lsp";
  avoid-system = "systemd|systemd-.*|sshd|Xorg|sway|Hyprland";
  avoid-shells = "emacs|vim|nvim|fish|bash|tmux|herdr";
  avoid-browsers = ''zen|firefox|\.firefox-wrappe|opera|\.opera-wrapped'';
in
{
  options.kp2pml30.oom-killer = lib.mkEnableOption "earlyoom userspace OOM killer that prefers reaping dev tooling (LSP/cargo/compilers) before the kernel freezes the box";

  config = lib.mkIf cfg.oom-killer {
    services.earlyoom = {
      enable = true;
      # act while a little headroom remains so the killer itself can run
      freeMemThreshold = 5;
      freeSwapThreshold = 5;
      extraArgs = [
        "--prefer"
        "^(${prefer-compiler}|${prefer-linker}|${prefer-lsp})$"
        "--avoid"
        "^(${avoid-system}|${avoid-shells}|${avoid-browsers})$"
      ];
    };
  };
}
