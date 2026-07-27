{
  pkgs,
  lib,
  config,
  utils,
  ...
}:
let
  cfg = config.kp2pml30.damn-rust;
  username = config.kp2pml30.username;
  mountUnit = "${utils.escapeSystemdPath cfg.mountPoint}.mount";
in
lib.mkIf cfg.enable {
  boot.supportedFilesystems = [ "btrfs" ];

  systemd.services.damn-rust-image = {
    description = "Create the damn-rust sparse btrfs image";
    requiredBy = [ mountUnit ];
    before = [ mountUnit ];
    # the mount Requires= this, so a restart would tear the store out from
    # under whatever is building against it
    restartIfChanged = false;
    stopIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # ordering against the image's own filesystem, without pulling in
    # local-fs.target and closing a cycle through it
    unitConfig.RequiresMountsFor = builtins.dirOf cfg.image;
    path = with pkgs; [
      btrfs-progs
      e2fsprogs
      util-linux
    ];
    script = ''
      mkdir -p "$(dirname ${cfg.image})"
      if [ ! -e ${cfg.image} ]; then
        truncate -s ${cfg.size} ${cfg.image}
        # if the host filesystem is btrfs too, don't let it CoW the image
        chattr +C ${cfg.image} || true
      fi
      if [ -z "$(blkid -o value -s TYPE ${cfg.image} || true)" ]; then
        mkfs.btrfs -L damn-rust ${cfg.image}
      fi

      # unmounted, the mount point must not be writable: the symlinks into it
      # are absolute, so a build would otherwise quietly fill the root filesystem
      if ! mountpoint -q ${cfg.mountPoint}; then
        mkdir -p ${cfg.mountPoint}
        chmod 0555 ${cfg.mountPoint}
      fi
    '';
  };

  systemd.mounts = [
    {
      what = cfg.image;
      where = cfg.mountPoint;
      type = "btrfs";
      # compress-force: plain compress= samples the first blocks and then marks
      # the whole file no-compress for good, which build artifacts trip a lot
      options = "loop,compress-force=zstd,noatime";
      wantedBy = [ "multi-user.target" ];
      # this mount is not part of local-fs.target: it is backed by a file that
      # lives on it, so the default deps would be a cycle
      unitConfig.DefaultDependencies = false;
      conflicts = [ "umount.target" ];
      before = [ "umount.target" ];
    }
  ];

  # btrfs has no uid= mount option, so hand the mount over after it is up
  systemd.services.damn-rust-own = {
    description = "Give ${username} the damn-rust store";
    requires = [ mountUnit ];
    after = [ mountUnit ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      chown ${username}:users ${cfg.mountPoint}
      chmod 0755 ${cfg.mountPoint}
    '';
  };

  security.sudo.extraRules = [
    {
      users = [ username ];
      commands = [
        {
          command = "${pkgs.util-linux}/bin/fstrim -v ${cfg.mountPoint}";
          options = [ "NOPASSWD" ];
        }
        {
          # compsize walks the extent tree, which needs CAP_SYS_ADMIN
          command = "${pkgs.compsize}/bin/compsize ${cfg.mountPoint}";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = [
    (pkgs.symlinkJoin {
      name = "damn-rust";
      paths = [
        (pkgs.writers.writePython3Bin "damn-rust" {
          doCheck = false;
          libraries = [ pkgs.python3Packages.argcomplete ];
        } (builtins.readFile ./damn-rust.py))
      ];
      buildInputs = [
        pkgs.makeWrapper
        pkgs.python3Packages.argcomplete
      ];
      postBuild = ''
        wrapProgram $out/bin/damn-rust \
          --set DAMN_RUST_ROOT ${cfg.mountPoint} \
          --set DAMN_RUST_IMAGE ${cfg.image} \
          --set DAMN_RUST_FSTRIM ${pkgs.util-linux}/bin/fstrim \
          --set DAMN_RUST_COMPSIZE ${pkgs.compsize}/bin/compsize

        # completions come straight off the argparse parser
        mkdir -p $out/share/bash-completion/completions $out/share/fish/vendor_completions.d
        register-python-argcomplete --shell bash damn-rust \
          > $out/share/bash-completion/completions/damn-rust
        register-python-argcomplete --shell fish damn-rust \
          > $out/share/fish/vendor_completions.d/damn-rust.fish
      '';
    })
  ];
}
