{
  config,
  pkgs,
  lib,
  data,
  ...
}:
let
  cfg = config.kp2pml30.zfs;
  ssh = cfg.initrd-ssh;

  systemdInitrd = config.boot.initrd.systemd.package;

  unlockUser = "boot-unlocker";
  unlockSocket = "/run/boot-unlock.sock";
  unlockStatus = "/run/zfs-load-key-${cfg.pool}.status";

  # Login shell and ForceCommand of the unlock user, so args are ignored. The
  # user can only hand a passphrase to the root-side answerer below.
  unlockClient = pkgs.writeShellScript "boot-unlock-client" ''
    # Drop keystrokes buffered before the prompt (type-ahead, terminal replies).
    while IFS= read -r -s -t 0.3 _; do :; done
    # zfs only gets 3 tries; don't burn one on a stray Enter.
    pw=
    while [ -z "$pw" ]; do
      IFS= read -r -s -p "Passphrase for ${cfg.pool}: " pw || exit 1
      echo
    done
    out=$(printf '%s\n' "$pw" | ${pkgs.netcat-openbsd}/bin/nc -N -U ${unlockSocket})
    unset pw
    if [ -z "$out" ]; then
      echo "not delivered: another unlock in progress?"
      exit 1
    fi
    echo "$out"
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
        description = "Keys of the `${unlockUser}` user, which can only type the passphrase.";
      };

      rootDebugShell = lib.mkEnableOption "root bash over initrd ssh, with the same keys";

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

      tailscale = {
        enable = lib.mkEnableOption "reaching the initrd sshd over the tailnet";

        stateFile = lib.mkOption {
          type = lib.types.str;
          default = "/initrd-tailscale/tailscaled.state";
          description = ''
            tailscaled state, path relative to the boot partition root. A node identity
            of its own, enrolled once from the installer; unencrypted at rest.
          '';
        };
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
        # nixpkgs gives up after 3 wrong passphrases and the boot is stuck until a
        # power cycle; the unit below retries forever with backoff instead.
        boot.zfs.requestEncryptionCredentials = false;

        boot.initrd.systemd = {
          enable = true;
          services."zfs-load-key-${cfg.pool}" = {
            description = "Load the ${cfg.pool} encryption key";
            requires = [ "zfs-import-${cfg.pool}.service" ];
            after = [ "zfs-import-${cfg.pool}.service" ];
            # The other datasets mount under /sysroot, hence after it.
            requiredBy = [ "sysroot.mount" ];
            before = [
              "sysroot.mount"
              "shutdown.target"
            ];
            conflicts = [ "shutdown.target" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "infinity";
            };
            path = [
              pkgs.coreutils
              config.boot.zfs.package
            ];
            # The status file tells the ssh answerer how an attempt went.
            script = ''
              status=${unlockStatus}
              delay=2
              until [ "$(zfs get -H -o value keystatus ${cfg.pool})" = available ]; do
                if ${systemdInitrd}/bin/systemd-ask-password --timeout=0 "Enter key for ${cfg.pool}:" | zfs load-key ${cfg.pool}; then
                  break
                fi
                echo "wrong passphrase, next try in ''${delay}s" > "$status"
                sleep "$delay"
                delay=$((delay * 2 > 60 ? 60 : delay * 2))
              done
              echo "${cfg.pool} unlocked" > "$status"
            '';
          };
        };

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
            "${pkgs.bash}/bin/bash"
            "${pkgs.netcat-openbsd}/bin/nc"
            "${systemdInitrd}/lib/systemd/systemd-reply-password"
            "${unlockClient}"
          ]
          ++ lib.optional ssh.rootDebugShell "${pkgs.bashInteractive}/bin/bash";

          users.${unlockUser} = {
            uid = data.uids.${unlockUser};
            group = unlockUser;
            shell = "${unlockClient}";
          };
          groups.${unlockUser}.gid = data.gids.${unlockUser};
          users.root.shell = lib.mkIf ssh.rootDebugShell "${pkgs.bashInteractive}/bin/bash";

          contents = {
            "/etc/ssh/authorized_keys.d/${unlockUser}".text = lib.concatStringsSep "\n" ssh.authorizedKeys;
            # nixpkgs insists on root keys; without the debug shell, root gets none.
            "/etc/ssh/authorized_keys.d/root".text = lib.mkIf (!ssh.rootDebugShell) (lib.mkForce "");
          };

          sockets.boot-unlock = {
            description = "Passphrase handoff from ${unlockUser}";
            wantedBy = [ "sockets.target" ];
            socketConfig = {
              ListenStream = unlockSocket;
              SocketUser = "root";
              SocketGroup = unlockUser;
              SocketMode = "0660";
              Accept = true;
              MaxConnections = 1;
              RemoveOnStop = true;
            };
          };

          # Root side: forwards the passphrase only to the pool's own
          # ask-password request, then reports whether the key loaded.
          services."boot-unlock@" = {
            description = "Answer the ${cfg.pool} passphrase request";
            unitConfig.DefaultDependencies = false;
            serviceConfig = {
              StandardInput = "socket";
              StandardOutput = "socket";
              StandardError = "journal";
            };
            path = [
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gnused
              config.boot.zfs.package
            ];
            script = ''
              asks() {
                for ask in /run/systemd/ask-password/ask.*; do
                  [ -e "$ask" ] && grep -qxF 'Message=Enter key for ${cfg.pool}:' "$ask" && echo "$ask"
                done
              }

              IFS= read -r pw || exit 1
              if [ -z "$pw" ]; then
                echo "empty passphrase, not sent"
                exit 1
              fi
              answered=$(asks || true)
              if [ -z "$answered" ]; then
                unset pw
                if [ -e ${unlockStatus} ]; then
                  cat ${unlockStatus}
                else
                  echo "nothing is asking for the ${cfg.pool} passphrase"
                fi
                exit 1
              fi
              rm -f ${unlockStatus}
              for ask in $answered; do
                sock=$(sed -n 's/^Socket=//p' "$ask")
                printf '%s' "$pw" | ${systemdInitrd}/lib/systemd/systemd-reply-password 1 "$sock" || true
              done
              unset pw

              # zfs-load-key-${cfg.pool} reports the outcome of this attempt.
              for _ in $(seq 60); do
                if [ -e ${unlockStatus} ]; then
                  cat ${unlockStatus}
                  exit 0
                fi
                sleep 0.5
              done
              echo "no answer from zfs after 30s, check the console"
              exit 1
            '';
          };

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
          extraConfig = ''
            AllowUsers ${unlockUser}${lib.optionalString ssh.rootDebugShell " root"}
            DisableForwarding yes
            PermitTunnel no

            Match User ${unlockUser}
              ForceCommand ${unlockClient}
          '';
        };
      })

      (lib.mkIf (cfg.unlock == "initrd-ssh" && ssh.tailscale.enable) {
        boot.initrd.systemd = {
          storePaths = [ "${config.services.tailscale.package}/bin/tailscaled" ];
          # TLS to the control server also needs a sane clock: put the board's
          # RTC driver into the initrd, the kernel's hctosys does the rest.
          contents."/etc/ssl/certs/ca-certificates.crt".source = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

          # Userspace netstack: no tun, no netfilter, and inbound tailnet
          # connections are proxied to localhost, where sshd listens.
          services.initrd-tailscaled = {
            description = "Tailnet access to the initrd sshd";
            wantedBy = [ "initrd.target" ];
            requires = [ "boot.mount" ];
            after = [
              "boot.mount"
              "systemd-networkd.service"
              "systemd-resolved.service"
            ];
            before = [ "shutdown.target" ];
            conflicts = [ "shutdown.target" ];
            unitConfig = {
              DefaultDependencies = false;
              ConditionPathExists = "/boot${ssh.tailscale.stateFile}";
            };
            path = [ pkgs.coreutils ];
            # /boot is mounted read-only; tailscaled needs a writable state dir.
            preStart = ''
              install -d -m 0700 /run/initrd-tailscale
              install -m 0600 /boot${ssh.tailscale.stateFile} /run/initrd-tailscale/tailscaled.state
            '';
            # /run survives switch-root; don't leave the node key to stage 2.
            postStop = "rm -rf /run/initrd-tailscale";
            serviceConfig = {
              ExecStart = lib.concatStringsSep " " [
                "${config.services.tailscale.package}/bin/tailscaled"
                "--statedir=/run/initrd-tailscale"
                "--socket=/run/initrd-tailscale/tailscaled.sock"
                "--tun=userspace-networking"
                "--no-logs-no-support"
              ];
              Restart = "on-failure";
              RestartSec = 5;
            };
          };

          # netstack proxies to localhost only for addresses in tailscale's own
          # ranges; others it dials as-is, so a custom IPv4 prefix needs the
          # node's address on lo. Re-pulled by every tailscaled (re)start.
          services.initrd-tailscale-lo =
            let
              addrFile = "/run/initrd-tailscale-lo.addr";
            in
            {
              description = "Own tailnet IPv4 on lo for the initrd netstack";
              wantedBy = [
                "initrd.target"
                "initrd-tailscaled.service"
              ];
              bindsTo = [ "initrd-tailscaled.service" ];
              after = [ "initrd-tailscaled.service" ];
              before = [ "shutdown.target" ];
              conflicts = [ "shutdown.target" ];
              unitConfig.DefaultDependencies = false;
              path = [
                config.services.tailscale.package
                pkgs.iproute2
                pkgs.coreutils
              ];
              script = ''
                until a=$(tailscale --socket=/run/initrd-tailscale/tailscaled.sock ip -4 2>/dev/null | head -n1) && [ -n "$a" ]; do
                  sleep 2
                done
                ip addr replace "$a/32" dev lo
                echo "$a" > ${addrFile}
              '';
              preStop = ''
                if [ -e ${addrFile} ]; then
                  ip addr del "$(cat ${addrFile})/32" dev lo || true
                  rm -f ${addrFile}
                fi
              '';
              serviceConfig.RemainAfterExit = true;
            };
        };
      })
    ]
  );
}
