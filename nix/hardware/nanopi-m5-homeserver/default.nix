{
  config,
  pkgs,
  lib,
  modulesPath,
  data,
  ...
}:
{
  imports = [
    ../common.nix
  ];

  # Declares & gates kp2pml30.hardware.wireless (-> wireless.nix / iwd).
  kp2pml30.hardware.wireless = true;

  nixpkgs.hostPlatform = "aarch64-linux";

  # Not linuxPackages_latest: zfs does not build against it. 6.18 carries
  # rk3576-nanopi-m5.dts.
  boot.kernelPackages = pkgs.linuxPackages;

  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "rockchip/rk3576-nanopi-m5.dtb";

  # Headless; panfrost probe sometimes hangs the SoC after the gpu power domain
  # fails to ack.
  boot.blacklistedKernelModules = [ "panfrost" ];

  boot.kernelParams = [
    "console=tty1"
    # Matches the rk3576 boot ROM / rkbin TPL/SPL fixed baud (UART0_M0).
    "console=ttyS0,1500000n8"
  ];

  # SD/eMMC/NVMe and both RGMII ports, needed in the initrd for zfs import and
  # for the unlock sshd. The PCIe host controller is built in.
  boot.initrd.availableKernelModules = [
    "dw_mmc_rockchip"
    "dw_mmc_pltfm"
    "sdhci_of_dwcmshc"
    "mmc_block"
    "nvme"
    # RTC, so the initrd clock is sane enough for TLS to the headscale server
    "rtc_hym8563"
    "dwmac_rk"
    "stmmac_platform"
    "stmmac"
    "realtek"
    "motorcomm"
    "phy_rockchip_naneng_combphy"
  ];

  # hardware.enableRedistributableFirmware is set by ../common.nix.

  networking.useNetworkd = true;
  systemd.network.networks."10-eth" = {
    matchConfig.Name = "en* end*";
    networkConfig.DHCP = "yes";
  };
  # WiFi fallback: iwd associates (see ../wireless.nix), networkd does DHCP.
  systemd.network.networks."20-wlan" = {
    matchConfig.Name = "wl*";
    networkConfig.DHCP = "yes";
  };

  security.sudo.wheelNeedsPassword = false;

  # The box wedges every few days (answers ping, no userspace progress, journald
  # silent), likely the SD/dwmmc controller stalling with tasks stuck in D state.
  # The watchdog can miss that, so panic on a hung-task pileup and auto-reboot.
  boot.kernel.sysctl = {
    "kernel.hung_task_panic" = 1;
    "kernel.hung_task_timeout_secs" = 120;
    "kernel.panic" = 10;
    "kernel.panic_on_oops" = 1;
  };
}
