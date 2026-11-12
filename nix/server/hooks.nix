{
  config,
  lib,
  pkgs,
  data,
  kp2pml30-moe-backend,
  system,
  ...
}:
let
  cfg = config.kp2pml30.server;
  ports = cfg.ports;
  fqdn = data.network.addresses.hooks.fqdn;
  inherit (data.mail) domain;
  user = "hooks";
  credentials = "/run/credentials/hooks.service";
  # Mail routed to the secretary goes to the ya-coder harness when it runs here
  handoff = config.users.groups ? ya-coder;

  # The classifier runs once its DeepInfra key is in the flake and encrypted to this host
  llmKey = "keys/deepinfra-mail";
  llmRecipients = ../secrets/data + "/${llmKey}.recipients";
  classify =
    builtins.pathExists llmRecipients
    && lib.elem "nanopi-m5" (lib.splitString "\n" (builtins.readFile llmRecipients));

  # Each `<name>:<path under /run/secrets>` lands at ${credentials}/<name>
  secrets = {
    robo-kira = "mail/robo-kira.pass";
    violet = "mail/violet.pass";
  }
  // lib.optionalAttrs classify {
    llm = llmKey;
    master = "mail/hooks-master.pass";
  };

  # Plaintext tokens: nix/secrets/data/hooks/<name>.token, readable on mini only
  routes =
    let
      send = mailbox: token_sha256: {
        inherit token_sha256 mailbox;
        action = "send";
        # Widen per mailbox once drafts are reviewed; only the owner's domain for now
        allow = [ "*@${domain}" ];
      };
    in
    {
      "/alert" = {
        token_sha256 = "7cde05c2a8c3d933397f6efd556da2d96d9fb83bb9ff6d9b0e9e3775c8a399f9";
        action = "alert";
        mailbox = "robo-kira";
        to = "alerts-internal@${domain}";
      };
      "/mail/send/violet" =
        send "violet" "0c5ccc785f13871f20d1b0deed5bcf27b7d70bfd4b485ae56c51dd2306e65be4";
      "/mail/send/robo-kira" =
        send "robo-kira" "e7219f19d8931ebc929e73ec5de07900def2c62a729647d22e85fe35acf8d8f0";
    };

  hooksConfig = (pkgs.formats.toml { }).generate "hooks.toml" (
    {
      listen = "127.0.0.1:${toString ports.hooks}";
      max_url_len = 512;
      max_body = 64 * 1024;
      smtp = {
        host = "127.0.0.1";
        port = 465;
        tls_name = "mail.${domain}";
      };
      imap = {
        host = "127.0.0.1";
        port = 993;
        tls_name = "mail.${domain}";
      };
      mailboxes = lib.genAttrs [ "robo-kira" "violet" ] (name: {
        address = "${name}@${domain}";
        password_file = "${credentials}/${name}";
        imap_login = "${name}@${domain}";
      });
      inherit routes;
    }
    // lib.optionalAttrs classify {
      llm = {
        base_url = "https://api.deepinfra.com/v1/openai";
        model = "mistralai/Mistral-Small-3.2-24B-Instruct-2506";
        api_key_file = "${credentials}/llm";
      };
      watch.kp2pml30 = {
        login = "kp2pml30@${domain}*hooks";
        password_file = "${credentials}/master";
      }
      // lib.optionalAttrs handoff {
        handoff = {
          socket = "/run/ya-coder/harness.sock";
          account = "mailer";
          to = "coder";
        };
      };
    }
  );
in
lib.mkMerge [
  (lib.mkIf cfg.hooks {
    assertions = [
      {
        assertion = cfg.tunnel == "host";
        message = "hooks is served to vdsina over the tunnel";
      }
    ];

    users.users.${user} = {
      isSystemUser = true;
      uid = data.uids.${user};
      group = user;
    };
    users.groups.${user}.gid = data.gids.${user};

    systemd.services.hooks = {
      description = "Webhooks and mail classifier";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "decrypt-secrets.service"
        "postfix.service"
        "dovecot.service"
      ];
      requires = [ "decrypt-secrets.service" ];
      partOf = [ "decrypt-secrets.service" ];
      serviceConfig = {
        User = user;
        Group = user;
        SupplementaryGroups = lib.optional handoff "ya-coder";
        ExecStart = lib.escapeShellArgs [
          (lib.getExe kp2pml30-moe-backend.packages.${system}.kp2pml30-moe-hooks)
          "--config"
          hooksConfig
        ];
        LoadCredential = lib.mapAttrsToList (name: path: "${name}:/run/secrets/${path}") secrets;
        Restart = "on-failure";
        RestartSec = 5;

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
        UMask = "0077";
      };
    };

    # vdsina's TLS terminator hides client addresses, so this is 1 shared ceiling, not per client
    services.nginx.appendHttpConfig = ''
      limit_req_zone $server_name zone=hooks:64k rate=5r/s;
    '';
    services.nginx.virtualHosts.${fqdn} = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString ports.hooks}";
        # The service checks the same limits; these keep junk off it
        extraConfig = ''
          if ($request_uri ~ "^.{513}") {
            return 414;
          }
          limit_except GET POST {
            deny all;
          }
          limit_req zone=hooks burst=50 nodelay;
          limit_req_status 429;
          client_max_body_size 64k;
          proxy_read_timeout 45s;
          proxy_send_timeout 15s;
        '';
      };
    };
  })

  (lib.mkIf cfg.hooks-relay {
    assertions = [
      {
        assertion = !cfg.hooks && cfg.tunnel == "relay";
        message = "hooks-relay forwards to nanopi-m5's hooks through the tunnel";
      }
    ];
    kp2pml30.server.ingress.forward = [ fqdn ];
    # Only the TLS terminator connects from here; plain HTTP would carry bearer tokens in clear
    services.nginx.virtualHosts.${fqdn}.locations."/".extraConfig = ''
      if ($remote_addr != 127.0.0.1) {
        return 403;
      }
    '';
  })
]
