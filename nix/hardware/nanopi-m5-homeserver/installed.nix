{
  config,
  pkgs,
  ...
}:
let
  # Moment M.2 2280 512GB NVMe
  bootDevice = "/dev/disk/by-uuid/0006861b-0b4f-451e-a26c-b713cda3a10d";
in
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
    device = bootDevice;
    fsType = "ext4";
  };
  kp2pml30.zfs.initrd-ssh.bootDevice = bootDevice;

  # Rescue without the SD card: root in the initrd can import the pool, read
  # its journal, `nix copy` a generation into /sysroot and fix /boot (umount it
  # afterwards: u-boot ignores the ext4 journal).
  kp2pml30.zfs.initrd-ssh.rootDebugShell = true;
  boot.initrd.systemd.extraBin = {
    grep = "${pkgs.gnugrep}/bin/grep";
    sed = "${pkgs.gnused}/bin/sed";
    less = "${pkgs.less}/bin/less";
    chroot = "${pkgs.coreutils}/bin/chroot";
    blkdiscard = "${pkgs.util-linux}/bin/blkdiscard";
    cryptsetup = "${pkgs.cryptsetup}/bin/cryptsetup";
    journalctl = "${config.boot.initrd.systemd.package}/bin/journalctl";
    nix = "${config.nix.package}/bin/nix";
    nix-store = "${config.nix.package}/bin/nix-store";
    nix-daemon = "${config.nix.package}/bin/nix-daemon";
  };

  virtualisation.docker.enable = true;

  # `/` and friends come from kp2pml30.zfs.datasets.

  # Not a zvol: swapping onto zfs can deadlock under memory pressure. Fresh
  # random key every boot, so no hibernation. By PARTUUID: the filesystem UUID
  # is wiped on every boot.
  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/12f77ef1-15d7-4389-ac7f-e9cedcfcbe77";
      discardPolicy = "both";
      randomEncryption = {
        enable = true;
        allowDiscards = true;
      };
    }
  ];
}
