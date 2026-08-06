{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.kp2pml30.zfs;
  ssh = cfg.initrd-ssh;

  systemdInitrd = config.boot.initrd.systemd.package;

  # `ssh root@host` lands straight on the passphrase prompt; `ssh root@host cmd`
  # still runs cmd, so the initrd stays debuggable.
  unlockShell = pkgs.writeShellScriptBin "initrd-unlock-shell" ''
    if [ $# -gt 0 ]; then
      exec ${pkgs.bashInteractive}/bin/bash "$@"
    fi
    exec ${systemdInitrd}/bin/systemd-tty-ask-password-agent --query
  '';
in
{
  options.kp2pml30.zfs = {
    enable = lib.mkEnableOption "root on encrypted ZFS";

    pool = lib.mkOption {
      type = lib.types.str;
      default = "rpool";
      description = "Root pool name. Creation flags live in the host's README.";
    };

    datasets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        "/" = "${cfg.pool}/root";
        "/nix" = "${cfg.pool}/nix";
        "/var" = "${cfg.pool}/var";
        "/home" = "${cfg.pool}/home";
      };
      defaultText = lib.literalExpression ''{ "/" = "''${pool}/root"; ... }'';
      description = "Mountpoint -> dataset. All of them must be `mountpoint=legacy`.";
    };

    unlock = lib.mkOption {
      type = lib.types.enum [
        "console"
        "initrd-ssh"
      ];
      default = "console";
      description = "Where the passphrase is typed: the local console, or an sshd running in the initrd.";
    };

    initrd-ssh = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 22;
      };

      authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };

      bootDevice = lib.mkOption {
        type = lib.types.str;
        default = "/dev/disk/by-label/BOOT";
        description = "Unencrypted boot partition, mounted in the initrd to read the host key.";
      };

      hostKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/initrd-ssh/ssh_host_ed25519_key";
        description = ''
          Ed25519 private key, path relative to the boot partition root. Kept off the
          nix store: the store is world-readable and gets pushed to the binary cache.
          Generate it once on the box, it is a boot-time-only key.
        '';
      };

      matchName = lib.mkOption {
        type = lib.types.str;
        default = "en* eth*";
        description = "systemd-networkd Name match for the initrd DHCP network.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = config.networking.hostId != null;
            message = "kp2pml30.zfs requires networking.hostId";
          }
        ];

        boot.supportedFilesystems.zfs = true;
        # Imports are driven by the initrd's device units, never by a stale cachefile.
        boot.zfs.forceImportRoot = false;
        boot.zfs.requestEncryptionCredentials = true;

        fileSystems = lib.mapAttrs (_: dataset: {
          device = dataset;
          fsType = "zfs";
        }) cfg.datasets;

        services.zfs = {
          autoScrub.enable = true;
          trim.enable = true;
        };
      }

      (lib.mkIf (cfg.unlock == "initrd-ssh") {
        assertions = [
          {
            assertion = ssh.authorizedKeys != [ ];
            message = "kp2pml30.zfs.initrd-ssh.authorizedKeys is empty; the box would be unbootable";
          }
        ];

        # The boot partition is mounted in the initrd to read the host key.
        boot.initrd.availableKernelModules = [ "ext4" ];

        boot.initrd.systemd = {
          enable = true;
          network.enable = true;
          network.networks."10-unlock" = {
            matchConfig.Name = ssh.matchName;
            networkConfig.DHCP = "yes";
          };

          storePaths = [
            "${systemdInitrd}/bin/systemd-tty-ask-password-agent"
            (lib.getExe unlockShell)
          ];

          users.root.shell = lib.getExe unlockShell;

          mounts = [
            {
              where = "/boot";
              what = ssh.bootDevice;
              type = "ext4";
              options = "ro";
              unitConfig.DefaultDependencies = false;
            }
          ];

          # Fail closed: no key, no sshd. Recovery is then UART-only, which beats
          # typing the passphrase into an unauthenticated host.
          services.sshd = {
            requires = [ "initrd-ssh-host-key.service" ];
            after = [ "initrd-ssh-host-key.service" ];
          };

          services.initrd-ssh-host-key = {
            description = "Load the initrd SSH host key off the boot partition";
            wantedBy = [ "initrd.target" ];
            before = [ "sshd.service" ];
            requires = [ "boot.mount" ];
            after = [ "boot.mount" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            path = [ pkgs.coreutils ];
            script = ''
              install -D -m 0600 /boot${ssh.hostKeyFile} /etc/ssh/ssh_host_ed25519_key
            '';
          };
        };

        boot.initrd.network.ssh = {
          enable = true;
          port = ssh.port;
          authorizedKeys = ssh.authorizedKeys;
          # HostKey is left unset so sshd picks up the key the unit above installs.
          hostKeys = [ ];
          ignoreEmptyHostKeys = true;
        };
      })
    ]
  );
}
