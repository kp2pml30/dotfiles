{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.kp2pml30.vm;
  vm = import ./lib.nix cfg.name;

  # deterministic locally-administered address, so the guest keeps its lease
  mac =
    let
      h = builtins.hashString "sha256" cfg.name;
      byte = i: builtins.substring (2 * i) 2 h;
    in
    "02:00:00:${byte 0}:${byte 1}:${byte 2}";
in
{
  options.kp2pml30.vm = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "MicroVM name; must match this nixosConfigurations attribute and the host's kp2pml30.vms entry.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "Guest user that owns the work dir and drives nix through the host daemon.";
    };
    cid = lib.mkOption {
      type = lib.types.ints.positive;
      description = "vsock context id, unique per host, >= 3. Used for ssh from the host (`microvm -s <name>`).";
    };
    mem = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8192;
      description = "RAM in MiB.";
    };
    vcpu = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Virtual cores.";
    };
  };

  config = {
    networking = {
      hostName = cfg.name;
      useDHCP = lib.mkForce false;
      useNetworkd = true;
    };
    systemd.network.networks."10-eth" = {
      matchConfig.Type = "ether";
      networkConfig.DHCP = "yes";
    };

    microvm = {
      hypervisor = "qemu";
      inherit (cfg) mem vcpu;

      shares = [
        # The host owns the store; the guest never writes one. No writable
        # overlay on purpose: it would give the guest a second, diverging db.
        # `cache = "auto"` keeps virtiofsd's 1s dentry timeouts, so a path the
        # host just built can read as missing for up to a second; "never" trades
        # that away for a lookup round trip on every store access.
        {
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/store";
          proto = "virtiofs";
          readOnly = true;
        }
        {
          tag = "vm-work";
          source = vm.workDir;
          mountPoint = vm.workDir;
          proto = "virtiofs";
        }
      ];

      interfaces = [
        {
          type = "user";
          id = "vm-${cfg.name}";
          inherit mac;
        }
      ];

      vsock = {
        cid = cfg.cid;
        ssh.enable = true;
      };
    };

    # Everything outside the work dir is tmpfs and dies with the VM, so the
    # user's home lives in the share; home-manager follows users.users.<u>.home.
    users.users.${cfg.user}.home = vm.homeDir;
    # a guest-side collect would run against the read-only store
    home-manager.users.${cfg.user}.nix.gc.automatic = lib.mkForce false;
    systemd.tmpfiles.rules = [
      "d ${vm.homeDir} 0700 ${cfg.user} users -"
      "z ${vm.identityFile} 0600 ${cfg.user} users -"
    ];

    programs.ssh.extraConfig = ''
      Host ${vm.hostAddress}
        User ${vm.builderUser}
        IdentityFile ${vm.identityFile}
        IdentitiesOnly yes
        UserKnownHostsFile ${vm.knownHostsFile}
    '';

    nix = {
      settings.extra-experimental-features = [ "mounted-ssh-store" ];

      # The host is the only store owner; a guest daemon would be a second
      # writer against the same /nix/store.
      gc.automatic = lib.mkForce false;
      optimise.automatic = lib.mkForce false;
    };
    systemd.services.nix-daemon.enable = false;
    systemd.sockets.nix-daemon.enable = false;

    # Deliberately pam_env rather than nix.conf or environment.variables:
    # boot-time nix (microvm's registerClosure, home-manager activation, which
    # runs a login shell) must keep using the local db, while every login
    # session goes to the host.
    environment.sessionVariables.NIX_REMOTE = "mounted-ssh-ng://${vm.builderUser}@${vm.hostAddress}";
    security.sudo.extraConfig = ''
      Defaults env_keep += "NIX_REMOTE"
    '';

    # `nixos-rebuild` here would write to a read-only store.
    system.switch.enable = lib.mkForce false;
  };
}
