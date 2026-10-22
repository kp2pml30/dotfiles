{ data, ... }:
{
  # Pinned rather than TOFU: whoever answers here gets the pool passphrase.
  programs.ssh = {
    knownHosts.nanopi-m5-initrd.publicKey = data.ssh-keys.nanopi-m5-initrd;
    extraConfig = ''
      Host nanopi-boot
        HostName nanopi-m5-initrd.ts.kp2pml30.moe
        User boot-unlocker
        HostKeyAlias nanopi-m5-initrd
        RequestTTY yes
    '';
  };
}
