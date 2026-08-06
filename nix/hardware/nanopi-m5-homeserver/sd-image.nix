{
  pkgs,
  modulesPath,
  ...
}:
let
  uboot = pkgs.callPackage ./uboot.nix { };
in
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ./default.nix
  ];

  sdImage.firmwarePartitionOffset = 16;

  sdImage.postBuildCommands = ''
    dd if=${uboot}/u-boot-rockchip.bin \
      of=$img \
      bs=512 seek=64 \
      conv=notrunc,fsync
  '';

  # This image doubles as the installer for the root-on-zfs system (see README).
  boot.supportedFilesystems.zfs = true;
  boot.zfs.forceImportRoot = false;
  environment.systemPackages = with pkgs; [
    zfs
    parted
    gptfdisk
    e2fsprogs
  ];
}
