{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.kp2pml30.server;
  nora = import ../nora/common.nix;
  package = pkgs.callPackage ../nora/package.nix { src = inputs.nora; };
  stateDir = "/var/lib/nora";

  configFile = (pkgs.formats.toml { }).generate "nora.toml" {
    # Not opened in the firewall: reachable over the trusted tailnet only
    server = {
      host = "::";
      port = cfg.ports.nora;
      public_url = nora.url;
    };
    storage.path = stateDir;
    # No users, so nothing can be published: a pure pull-through cache
    auth = {
      enabled = true;
      anonymous_read = true;
      token_storage = "${stateDir}/tokens";
    };
    curation.mode = "off";
    # Logs every cache hit to an append-only file otherwise
    audit.mode = "off";
    registries.enable = [
      "cargo"
      "npm"
      "pypi"
      "go"
    ];
    gc.enabled = true;
    # Cached files are re-fetched on demand, so expiring by cache age is safe
    retention = {
      enabled = true;
      rules = [
        {
          registry = "*";
          older_than_days = 30;
        }
      ];
    };
  };
in
{
  config = lib.mkIf cfg.nora {
    systemd.services.nora = {
      description = "NORA package cache";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        NORA_CONFIG_PATH = configFile;
        NORA_CONFIG_STRICT = "true";
      };
      serviceConfig = {
        ExecStart = "${lib.getExe package} serve";
        Restart = "on-failure";
        # EX_CONFIG: a bad config won't fix itself
        RestartPreventExitStatus = 78;

        DynamicUser = true;
        StateDirectory = "nora";
        WorkingDirectory = stateDir;
        LimitNOFILE = 65535;

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
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
      };
    };
  };
}
