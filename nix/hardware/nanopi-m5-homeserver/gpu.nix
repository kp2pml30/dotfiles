{ pkgs, ... }:
{
  # The gpu power domain fails to ack (and hangs the SoC) when it powers up after
  # regulator cleanup disabled the unclaimed rail. RK3576 pmdomain ignores
  # domain-supply on the gpu domain, so pin the rail instead.
  hardware.deviceTree.overlays = [
    {
      name = "rk3576-gpu-rail-always-on";
      dtsText = ''
        /dts-v1/;
        /plugin/;
        / { compatible = "friendlyarm,nanopi-m5"; };
        &vdd_gpu_s0 { regulator-always-on; };
      '';
    }
  ];

  # OpenCL via rusticl on panfrost
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.mesa.opencl ];
  };
  environment.variables.RUSTICL_ENABLE = "panfrost";
  environment.systemPackages = [ pkgs.clinfo ];
}
