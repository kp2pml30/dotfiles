{
  config,
  pkgs,
  lib,
  data,
  ...
}:
let
  cfg = config.kp2pml30.server;
in
{
  options.kp2pml30.server = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "kp2pml30";
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = null;
    };

    nginx = lib.mkEnableOption "";

    forgejo = lib.mkEnableOption "";
    forgejo-relay = lib.mkEnableOption "public forgejo front relaying HTTP and ssh to nanopi-m5";

    tunnel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "relay"
          "host"
        ]
      );
      default = null;
      description = "Side of the vdsina (relay) <-> nanopi-m5 (host) WireGuard tunnel";
    };

    nora = lib.mkEnableOption "nora package cache for the tailnet";

    dns = lib.mkEnableOption "";
    nix-cache = lib.mkEnableOption "";
    xray = lib.mkEnableOption "";
    headscale = lib.mkEnableOption "";
    mail-relay = lib.mkEnableOption "public mail front forwarding to nanopi-m5";

    zoneExtraRecords = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Raw records appended to the hostname's zone";
    };

    sitePath = lib.mkOption {
      type = lib.types.str;
    };
  };

  imports = [
    ./ports.nix
    ./ssh.nix
    ./nginx.nix
    ./boot.nix
    ./site.nix
    ./tunnel.nix
    ./ingress.nix
    ./forgejo.nix
    ./nora.nix
    ./dns.nix
    ./nix-cache.nix
    ./xray.nix
    ./headscale.nix
    ./mail/relay.nix
    ./secrets.nix
    ./firewall.nix
  ];

  config = lib.mkMerge [
    # Guarded so nix/server imports on hosts with no services (the nginx user
    # is undefined otherwise).
    (lib.mkIf cfg.nginx {
      users.groups.certreaders = {
        gid = data.gids.certreaders;
      };
      users.users.nginx.extraGroups = [ "certreaders" ];
    })
    {
      kp2pml30.machine-kind = "server";

      security.pam.sshAgentAuth.enable = true;

      users.users."${cfg.username}" = {
        isNormalUser = true;
        uid = data.uids."${cfg.username}";
        openssh.authorizedKeys.keys = [
          data.ssh-keys.kp2pml30-personal-pc
        ];
        # Only join groups that exist on this host (acme needs nginx).
        extraGroups = [
          "wheel"
        ]
        ++ lib.optional config.networking.networkmanager.enable "networkmanager"
        ++ lib.optional cfg.nginx "acme"
        ++ lib.optional config.virtualisation.docker.enable "docker";
        hashedPassword = "$6$UK6oHr2gPRYD4Rak$lgF.mYReC0jahNuI4kt0j/CsrajVzMprvp3HgjKwwsjYHU6/Ur9jfROXZbKhhpyCLRmnlCpWeRCbHEYO/jhIv/";
      };
    }
  ];
}
