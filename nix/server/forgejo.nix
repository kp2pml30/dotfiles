{
  config,
  pkgs,
  lib,
  data,
  ...
}:
let
  cfg = config.kp2pml30.server;
  ports = config.kp2pml30.server.ports;
  fcfg = config.services.forgejo;
  fqdn = data.network.addresses.forgejo.fqdn;
  tun = data.network.tunnel;

  # vdsina's sshd authenticates git users against nanopi-m5 and forwards the
  # session there; the relay key only reaches this dispatcher
  forgejoCli = lib.concatStringsSep " " [
    (lib.getExe fcfg.package)
    "--work-path ${fcfg.stateDir}"
    "--custom-path ${fcfg.customDir}"
    "--config ${fcfg.customDir}/conf/app.ini"
  ];
  dispatch = pkgs.writeShellScript "forgejo-relay-dispatch" ''
    set -euo pipefail
    cmd=''${SSH_ORIGINAL_COMMAND:-}
    case $cmd in
      "keys "*)
        read -r _ type key extra <<<"$cmd"
        [[ -z $extra && $type =~ ^[a-z0-9@.-]+$ && $key =~ ^[A-Za-z0-9+/=]+$ ]] || exit 1
        ${forgejoCli} keys -e ${fcfg.user} -u ${fcfg.user} -t "$type" -k "$key" \
          | ${lib.getExe pkgs.gnused} -nE 's/.* serv (key-[0-9]+).*/\1/p'
        ;;
      "serv "*)
        rest=''${cmd#serv }
        key=''${rest%% *}
        [[ $key =~ ^key-[0-9]+$ ]] || exit 1
        orig=''${rest#"$key"}
        SSH_ORIGINAL_COMMAND=''${orig# } exec ${forgejoCli} serv "$key"
        ;;
      *)
        exit 1
        ;;
    esac
  '';

  relayKey = "/run/forgejo-relay/key";
  relaySsh = lib.concatStringsSep " " [
    (lib.getExe pkgs.openssh)
    "-T -i ${relayKey}"
    "-o BatchMode=yes"
    "-o IdentitiesOnly=yes"
    "-o ConnectTimeout=10"
    "-o StrictHostKeyChecking=yes"
    "-o UserKnownHostsFile=${pkgs.writeText "forgejo-relay-known-hosts" ''
      ${tun.nanopi-m5.ipv4} ${data.ssh-keys.nanopi-m5-host}
    ''}"
  ];
  relayKeys = pkgs.writeShellScript "forgejo-relay-keys" ''
    set -euo pipefail
    id=$(${relaySsh} forgejo@${tun.nanopi-m5.ipv4} keys "$1" "$2")
    [[ $id =~ ^key-[0-9]+$ ]] || exit 0
    printf 'restrict,command="${relayServ} %s" %s %s\n' "$id" "$1" "$2"
  '';
  relayServ = pkgs.writeShellScript "forgejo-relay-serv" ''
    # Client-controlled; must never become an extra ssh option
    [[ ''${GIT_PROTOCOL:-} =~ ^[a-z0-9=:.]*$ ]] || unset GIT_PROTOCOL
    exec ${relaySsh} ''${GIT_PROTOCOL:+-o "SetEnv=GIT_PROTOCOL=$GIT_PROTOCOL"} \
      forgejo@${tun.nanopi-m5.ipv4} "serv $1 ''${SSH_ORIGINAL_COMMAND:-}"
  '';
in
lib.mkMerge [
  (lib.mkIf cfg.forgejo {
    users.users.forgejo.uid = data.uids.forgejo;
    users.groups.forgejo.gid = data.gids.forgejo;

    services.forgejo = {
      enable = true;
      database.type = "postgres";
      lfs.enable = true;
      settings = {
        server = {
          DOMAIN = fqdn;
          ROOT_URL = "https://${fqdn}/";
          HTTP_PORT = ports.forgejo;
        };
        service.DISABLE_REGISTRATION = true;
        # Upstream default minus repo.actions; enable per repo when wanted
        repository.DEFAULT_REPO_UNITS = lib.concatStringsSep "," [
          "repo.code"
          "repo.issues"
          "repo.pulls"
          "repo.releases"
          "repo.wiki"
          "repo.projects"
          "repo.packages"
        ];
        # Bare `uses: owner/action` resolves here, not to data.forgejo.org
        actions.DEFAULT_ACTIONS_URL = "self";
      };
    };
  })

  (lib.mkIf (cfg.forgejo && cfg.tunnel == "host") {
    services.nginx.virtualHosts.${fqdn}.locations."/" = {
      proxyPass = "http://127.0.0.1:${toString ports.forgejo}";
      proxyWebsockets = true;
      # LFS objects and HTTPS pushes
      extraConfig = "client_max_body_size 0;";
    };

    # Every relayed session comes from vdsina; a ban would cut off all git ssh
    services.fail2ban.ignoreIP = [ tun.vdsina.ipv4 ];

    users.users.forgejo.openssh.authorizedKeys.keys = [
      ''restrict,from="${tun.vdsina.ipv4}",command="${dispatch}" ${data.ssh-keys.forgejo-relay}''
    ];
  })

  (lib.mkIf cfg.forgejo-relay {
    assertions = [
      {
        assertion = !cfg.forgejo && cfg.tunnel == "relay";
        message = "forgejo-relay forwards to nanopi-m5's forgejo through the tunnel";
      }
    ];

    kp2pml30.server.ingress.forward = [ fqdn ];

    users.users.forgejo = {
      uid = data.uids.forgejo;
      group = "forgejo";
      isSystemUser = true;
      useDefaultShell = true;
    };
    users.groups.forgejo.gid = data.gids.forgejo;

    services.openssh.extraConfig = ''
      Match User forgejo
        AuthorizedKeysFile none
        AuthorizedKeysCommand /etc/ssh/forgejo-relay-keys %t %k
        AuthorizedKeysCommandUser forgejo
        AcceptEnv GIT_PROTOCOL
      Match All
    '';
    # sshd rejects commands under the group-writable /nix/store; mode makes a copy
    environment.etc."ssh/forgejo-relay-keys" = {
      source = relayKeys;
      mode = "0555";
    };

    # /run/secrets is root-only
    systemd.services.forgejo-relay-key = {
      description = "Install the forgejo relay ssh key";
      wantedBy = [ "multi-user.target" ];
      requires = [ "decrypt-secrets.service" ];
      after = [ "decrypt-secrets.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -m 0750 -o root -g forgejo ${dirOf relayKey}
        install -m 0400 -o forgejo -g forgejo /run/secrets/tunnel/forgejo-relay ${relayKey}
      '';
    };
  })
]
