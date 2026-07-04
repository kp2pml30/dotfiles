{
  config,
  lib,
  ...
}:
let
  cfg = config.kp2pml30;
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
        # names are matched against /proc/comm (truncated to 15 chars)
        "--prefer"
        "^(rust-analyzer|cargo|rustc|cc1|cc1plus|lto1|ld|clangd|ccls|gopls|.*-language-serve|.*-lsp)$"
        # never target session-critical processes
        "--avoid"
        "^(systemd|systemd-.*|sshd|Xorg|sway|Hyprland|nvim|fish|bash|tmux)$"
      ];
    };
  };
}
