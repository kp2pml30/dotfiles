{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.kp2pml30;
  syncCfg = cfg.sync-files;
  user = cfg.username;
  home = "/home/${user}";
  syncDir = "${home}/sync";
  uid = toString config.users.users.${user}.uid;
  gid = toString config.users.groups.users.gid;
  tailscaleEnabled = config.services.tailscale.enable;
  tailscaleInterface = config.services.tailscale.interfaceName;
  nixDevices = lib.mapAttrs (_: device: { inherit (device) id addresses; }) syncCfg.syncthing.devices;
  offNixDevices = lib.mapAttrs (_: dev: {
    id = dev.syncthing;
    addresses = [ "dynamic" ]; # roaming clients dial mini; never dialed by us
  }) (import ./off-nix-devices.nix);
  allDevices = nixDevices // offNixDevices;
  deviceNames = builtins.attrNames allDevices;
  hasDevices = deviceNames != [ ];
  stignore = pkgs.writeText "sync-stignore" ''
    /notes/decrypted/
    /notes/decrypted/**
    .stfolder/
  '';
in
{
  config = lib.mkIf syncCfg.enable {
    services.tailscale.enable = lib.mkDefault true;

    environment.systemPackages = with pkgs; [
      gocryptfs
      keepassxc
      kpcli
      keepmenu
      obsidian
      syncthing
      syncthingtray
    ];

    programs.fuse.userAllowOther = true;

    systemd.tmpfiles.rules = [
      "d ${syncDir} 0700 ${user} users - -"
      "d ${syncDir}/notes 0700 ${user} users - -"
      "d ${syncDir}/notes/encrypted 0700 ${user} users - -"
      "d ${syncDir}/notes/decrypted 0700 ${user} users - -"
      "d ${syncDir}/notes/public 0700 ${user} users - -"
    ];

    home-manager.users.${user} = { lib, ... }: {
      home.activation.makeSyncDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p ~/sync/notes/encrypted
        run mkdir -p ~/sync/notes/decrypted
        run mkdir -p ~/sync/notes/public
        run chmod 700 ~/sync ~/sync/notes ~/sync/notes/encrypted ~/sync/notes/decrypted ~/sync/notes/public

        if [ ! -e ~/sync/.stignore ]; then
          run install -m 0600 ${stignore} ~/sync/.stignore
        fi
      '';
    };

    services.syncthing = {
      enable = true;
      user = user;
      group = "users";
      dataDir = syncDir;
      configDir = "${home}/.config/syncthing";
      openDefaultPorts = false;
      overrideDevices = hasDevices;
      overrideFolders = hasDevices;
      settings = {
        devices = allDevices;
        folders = lib.mkIf hasDevices {
          sync = {
            label = "sync";
            path = syncDir;
            devices = deviceNames;
            type = "sendreceive";
            ignorePerms = true;
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "31536000";
              };
            };
          };
        };
        options = {
          globalAnnounceEnabled = false;
          relaysEnabled = false;
          natEnabled = false;
          urAccepted = -1;
        };
        gui = {
          address = "127.0.0.1:8384";
        };
      };
    };

    networking.firewall.interfaces = lib.mkIf tailscaleEnabled {
      ${tailscaleInterface} = {
        allowedTCPPorts = [ 22000 ];
        allowedUDPPorts = [
          22000
          21027
        ];
      };
    };

    systemd.services.syncthing = {
      after = lib.optional tailscaleEnabled "tailscaled.service";
      wants = lib.optional tailscaleEnabled "tailscaled.service";
    };

    systemd.services.gocryptfs-notes = {
      description = "Mount encrypted Obsidian notes";
      wantedBy = [ "multi-user.target" ];
      after = [ "decrypt-secrets.service" ];
      requires = [ "decrypt-secrets.service" ];
      unitConfig.ConditionPathExists = [
        "/run/secrets/fs/notes"
        "${syncDir}/notes/encrypted/gocryptfs.conf"
      ];
      path = [
        pkgs.coreutils
        pkgs.fuse3
        pkgs.gocryptfs
        pkgs.util-linux
      ];
      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "on-failure";
        RestartSec = "15s";
        ExecStartPre = [
          "${pkgs.coreutils}/bin/install -d -m 0700 -o ${user} -g users ${syncDir}/notes/encrypted"
          "${pkgs.coreutils}/bin/install -d -m 0700 -o ${user} -g users ${syncDir}/notes/decrypted"
        ];
        ExecStart = "${pkgs.gocryptfs}/bin/gocryptfs -fg -allow_other -force_owner ${uid}:${gid} -nosyslog -passfile /run/secrets/fs/notes ${syncDir}/notes/encrypted ${syncDir}/notes/decrypted";
        ExecStop = "${pkgs.util-linux}/bin/umount ${syncDir}/notes/decrypted";
      };
    };
  };
}
