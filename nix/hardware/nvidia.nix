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
      # 595.x does not build against recent mainline kernels. The driver config bakes
      # patchesOpen into generic.nix's first application, so `.override` can't reach
      # it; patch the open kernel-module derivation directly.
      base
      // {
        open = base.open.overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [
            ./nvidia-of_gpio.patch
            ./nvidia-strncpy.patch
            ./nvidia-drm-atomic-commit.patch
          ];
          # Upstream's `PAHOLE=awk '...'` gets word-split by gen-btf.sh on 7.x
          makeFlags = (o.makeFlags or [ ]) ++ [
            "PAHOLE_VARIABLES=PAHOLE=${pkgs.writeShellScript "nvidia-pahole" ''
              args=()
              for a in "$@"; do
                case $a in --lang_exclude=*) a="$a,c++" ;; esac
                args+=("$a")
              done
              exec ${pkgs.pahole}/bin/pahole "''${args[@]}"
            ''}"
          ];
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
