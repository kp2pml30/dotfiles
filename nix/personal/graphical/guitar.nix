{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.kp2pml30;
in
lib.mkIf cfg.guitar {
  # guitarix is a JACK client; pipewire's jack implementation serves it, so no
  # separate jack2 daemon.
  services.pipewire.jack.enable = true;

  # Amp simulation is monitored live, so the round trip has to stay inaudible.
  services.pipewire.extraConfig.pipewire."92-low-latency"."context.properties" = {
    "default.clock.rate" = 48000;
    "default.clock.quantum" = 256;
    "default.clock.min-quantum" = 64;
    "default.clock.max-quantum" = 512;
  };

  users.users.${cfg.username}.packages = with pkgs; [
    guitarix
    qpwgraph
  ];
}
