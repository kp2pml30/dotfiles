{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = config.kp2pml30;
  vmLib = import ./lib.nix;
  perVm = f: lib.mapAttrs' (name: vm: f name (vmLib name) vm) cfg.vms;
  builderUsers = map (name: (vmLib name).builderUser) (builtins.attrNames cfg.vms);
in
{
  imports = [ inputs.microvm.nixosModules.host ];

  options.kp2pml30.vms = lib.mkOption {
    default = { };
    description = ''
      MicroVM guests that share this host's /nix/store read-only and build
      through this host's nix-daemon. Each entry needs a matching
      `nixosConfigurations.<name>` importing ./guest.nix; sizing lives there,
      since microvm.nix reads the guest config out of the flake.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.autostart = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Start with the host.";
        };
      }
    );
  };

  config = lib.mkIf (cfg.vms != { }) {
    microvm.host.enable = true;
    microvm.vms = lib.mapAttrs (_: vm: {
      flake = inputs.self;
      inherit (vm) autostart;
    }) cfg.vms;

    # Without these the host would collect the closure of a running guest.
    # findRoots only resolves gcroot symlink -> symlink -> store path, so each
    # of microvm.nix's per-VM `current`/`booted` links needs its own entry; a
    # single link to the state dir would be dropped as a non-symlink target.
    systemd.tmpfiles.rules = [
      "d /nix/var/nix/gcroots/microvms 0755 root root -"
    ]
    ++ lib.concatMap (name: [
      "L+ /nix/var/nix/gcroots/microvms/${name}-current - - - - ${config.microvm.stateDir}/${name}/current"
      "L+ /nix/var/nix/gcroots/microvms/${name}-booted - - - - ${config.microvm.stateDir}/${name}/booted"
    ]) (builtins.attrNames cfg.vms);

    services.openssh = {
      enable = true;
      # reached from the guest via the slirp gateway, i.e. over loopback
      settings.AllowUsers = builderUsers;
      authorizedKeysFiles = [ "/var/lib/vm-keys/%u/authorized_keys" ];
    };

    users.groups.vm-builders = { };
    users.users = perVm (
      name: v: _:
      lib.nameValuePair v.builderUser {
        isSystemUser = true;
        group = "vm-builders";
        # ssh-ng runs `nix daemon --stdio`, which needs a real shell
        shell = pkgs.bashInteractive;
        description = "Untrusted nix-daemon client for MicroVM ${name}";
      }
    );

    systemd.services = perVm (
      name: v: _:
      lib.nameValuePair "vm-builder-key-${name}" {
        description = "Builder credentials for MicroVM '${name}'";
        before = [ "microvm@${name}.service" ];
        requiredBy = [ "microvm@${name}.service" ];
        # needs the host key that the guest is told to expect
        after = [ "sshd-keygen.service" ];
        wants = [ "sshd-keygen.service" ];
        wantedBy = [ "multi-user.target" ];
        path = with pkgs; [
          openssh
          coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail
          mkdir -p ${v.sshDir} ${builtins.dirOf v.authorizedKeysFile}

          if [ ! -e ${v.identityFile} ]; then
            ssh-keygen -t ed25519 -N "" -C ${v.builderUser} -f ${v.identityFile}
          fi

          # the account exists for exactly one operation
          printf 'command="%s daemon --stdio",restrict %s\n' \
            ${config.nix.package}/bin/nix "$(cat ${v.identityFile}.pub)" \
            > ${v.authorizedKeysFile}
          chmod 0644 ${v.authorizedKeysFile}

          printf '%s %s\n' ${v.hostAddress} "$(cat /etc/ssh/ssh_host_ed25519_key.pub)" \
            > ${v.knownHostsFile}
          chmod 0644 ${v.knownHostsFile}
        '';
      }
    );
  };
}
