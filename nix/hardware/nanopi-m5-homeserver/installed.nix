{
  ...
}:
{
  imports = [ ./default.nix ];

  # u-boot lives in SPI NOR; it only needs to find extlinux.conf on a filesystem
  # it can read. ext4 rather than btrfs: u-boot's btrfs driver is read-only and
  # barely exercised on rockchip, and a misread here means UART-only recovery.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible = {
    enable = true;
    # Each generation costs a kernel + a systemd/zfs initrd on /boot.
    configurationLimit = 5;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "ext4";
  };

  # `/` and friends come from kp2pml30.zfs.datasets.
}
