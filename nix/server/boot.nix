{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.kp2pml30.server;
in
{
  # Reboot if PID1 stops petting the SoC watchdog. No-op without /dev/watchdog.
  systemd.settings.Manager.RuntimeWatchdogSec = "5min";
}
