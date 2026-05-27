{ config
, pkgs
, lib
, data
, ...
}:
let
  cfg = config.kp2pml30.server;

  xray-config-base = builtins.toFile "xray.json" (builtins.toJSON (
    let base = builtins.fromJSON (builtins.readFile ./xray.json);
    in base // {
      inbounds = map (ib: ib // { port = config.kp2pml30.server.ports.xray-main; }) base.inbounds;
    }
  ));

  uidsDir = "/run/secrets/xray-uids";
in {
  config = lib.mkIf cfg.xray {
    users.users.xray = {
      isSystemUser = true;
      uid = data.uids.xray;
      group = "xray";
    };

    users.groups.xray = { gid = data.gids.xray; };

    systemd.services.xray-secrets = {
      description = "Generate Xray server configuration from decrypted UIDs";
      wantedBy = [ "xray.service" ];
      before = [ "xray.service" ];
      after = [ "decrypt-secrets.service" ];
      requires = [ "decrypt-secrets.service" ];
      unitConfig.ConditionPathIsDirectory = uidsDir;

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

      path = [ pkgs.jq pkgs.coreutils ];

      script = ''
        set -euo pipefail

        clients='[]'
        for f in ${uidsDir}/*; do
          [ -f "$f" ] || continue
          uuid=$(tr -d '[:space:]' < "$f")
          [ -n "$uuid" ] || continue
          clients=$(jq -c --arg uuid "$uuid" \
            '. + [{id: $uuid, flow: "xtls-rprx-vision"}]' <<<"$clients")
        done

        jq --argjson val "$clients" \
          '.inbounds[0].settings.clients = $val' \
          ${xray-config-base} > /run/secrets/xray-config.json
        chown xray:xray /run/secrets/xray-config.json
        chmod 440 /run/secrets/xray-config.json
      '';
    };
  };
}
