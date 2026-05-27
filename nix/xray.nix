{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.kp2pml30;

  xray-config-base = builtins.toFile "xray-client.json" (builtins.toJSON
    (builtins.fromJSON (builtins.readFile ./server/xray-client.json))
  );

  uuidFile = "/run/secrets/xray-uids/${cfg.xray-client-id}";
in {
  options.kp2pml30.xray-client = lib.mkEnableOption "";
  options.kp2pml30.xray-client-id = lib.mkOption {
    type = lib.types.str;
    description = "ID to select the correct UUID from secrets";
  };

  config = lib.mkIf cfg.xray-client {
    services.xray = {
      enable = true;
      settingsFile = "/run/secrets/xray-client-config.json";
    };

    systemd.services.xray-client-secrets = {
      description = "Generate Xray client configuration";
      wantedBy = [ "xray.service" ];
      before = [ "xray.service" ];
      after = [ "decrypt-secrets.service" ];
      requires = [ "decrypt-secrets.service" ];
      unitConfig.ConditionPathExists = uuidFile;

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

      script = ''
        set -euo pipefail
        UUID=$(tr -d '[:space:]' < ${uuidFile})
        ${pkgs.jq}/bin/jq --arg uuid "$UUID" \
          '.outbounds[0].settings.vnext[0].users[0].id = $uuid' \
          ${xray-config-base} > /run/secrets/xray-client-config.json
        chmod 444 /run/secrets/xray-client-config.json
      '';
    };
  };
}
