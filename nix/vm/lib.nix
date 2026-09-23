# Naming contract between the host module (./default.nix) and the guest module
# (./guest.nix). The work dir must resolve to the same absolute path on both
# sides: nix records indirect GC roots by the absolute path of the result
# symlink, and the host is the one who later resolves them.
name: rec {
  workDir = "/vms/${name}";
  homeDir = "${workDir}/home";

  sshDir = "${workDir}/ssh";
  identityFile = "${sshDir}/id_ed25519";
  knownHostsFile = "${sshDir}/known_hosts";

  # slirp gateway; qemu routes it to the host's loopback
  hostAddress = "10.0.2.2";

  builderUser = "vm-${name}";
  authorizedKeysFile = "/var/lib/vm-keys/${builderUser}/authorized_keys";
}
