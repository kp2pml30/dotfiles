{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    package =
      let
        base = config.boot.kernelPackages.nvidiaPackages.beta;
      in
      # of_gpio.h was dropped from mainline; 595.x still includes it unconditionally.
      # The driver config bakes patchesOpen into generic.nix's first application, so
      # `.override` can't reach it; patch the open kernel-module derivation directly.
      base
      // {
        open = base.open.overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [ ./nvidia-of_gpio.patch ];
        });
      };
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
  };

  hardware.nvidia-container-toolkit.enable = true;
}
