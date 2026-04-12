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

  decryptSecrets = pkgs.writeShellScript "decrypt-secrets" ''
    set -euo pipefail

    source /var/lib/secrets/.env

    if [ -z "''${KP2_DOTFILES_SECRET_KEY:-}" ]; then
      echo "Error: KP2_DOTFILES_SECRET_KEY environment variable not set" >&2
      exit 1
    fi

    ${pkgs.openssl}/bin/openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -base64 -d -k "$KP2_DOTFILES_SECRET_KEY" -in "${./server/secrets.yaml}" | ${pkgs.yq}/bin/yq --arg id "${cfg.xray-client-id}" '.XRAY_UIDS[] | select(.id == $id) | .uid' -r
  '';

  generateXrayConfig = pkgs.writeShellScript "generate-xray-client-config" ''
    set -euo pipefail

    UUID=$(${decryptSecrets})

    cat "${xray-config-base}" | \
      ${pkgs.jq}/bin/jq --arg uuid "$UUID" '.outbounds[0].settings.vnext[0].users[0].id = $uuid'
  '';
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

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        EnvironmentFile = "/var/lib/secrets/.env";
      };

      script = ''
        mkdir -p /run/secrets
        ${generateXrayConfig} > /run/secrets/xray-client-config.json
        chmod 444 /run/secrets/xray-client-config.json
      '';
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/secrets 0750 root root -"
      "d /run/secrets 0755 root root -"
    ];
  };
}
