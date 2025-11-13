{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.kp2pml30.server;

  # Script to decrypt secrets.yaml and extract XRAY_UIDS
  decryptSecrets = pkgs.writeShellScript "decrypt-secrets" ''
    set -euo pipefail

    source /var/lib/secrets/.env

    if [ -z "''${KP2_DOTFILES_SECRET_KEY:-}" ]; then
      echo "Error: KP2_DOTFILES_SECRET_KEY environment variable not set" >&2
      exit 1
    fi

    if [ ! -f "${./secrets.yaml}" ]; then
      echo "Error: secrets.yaml not found" >&2
      exit 1
    fi

    # Decrypt and parse XRAY_UIDS
    ${pkgs.openssl}/bin/openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -base64 -d -k "$KP2_DOTFILES_SECRET_KEY" -in "${./secrets.yaml}" | ${pkgs.yq}/bin/yq '.XRAY_UIDS[]' -r
  '';

  xray-config-base = builtins.toFile "xray.json" (builtins.readFile ./xray.json);

  # Script to generate complete xray configuration
  generateXrayConfig = pkgs.writeShellScript "generate-xray-config" ''
    set -euo pipefail

    ALL_IDS="["

    first=true
    while IFS= read -r uuid; do
      if [ "$first" = true ]; then
        first=false
      else
        ALL_IDS="$ALL_IDS,"
      fi
      ALL_IDS="$ALL_IDS{\"id\":\"$uuid\",\"flow\": \"xtls-rprx-vision\"}"
    done < <(${decryptSecrets})

    ALL_IDS="$ALL_IDS]"

    cat "${xray-config-base}" | \
      jq --argjson val "$ALL_IDS" '.inbounds.[0].settings.clients = $val'
  '';

in {
  options.kp2pml30.server.secretsDir = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/secrets";
    description = "Directory for secrets management";
  };

  config = lib.mkIf cfg.xray {
    # Ensure xray user and group exist
    users.users.xray = {
      isSystemUser = true;
      group = "xray";
    };

    users.groups.xray = {};

    # Create a systemd service to decrypt and prepare xray clients config
    systemd.services.xray-secrets = {
      description = "Decrypt Xray client configuration";
      wantedBy = [ "xray.service" ];
      before = [ "xray.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        EnvironmentFile = "${cfg.secretsDir}/.env";
      };

      script = ''
        mkdir -p /run/secrets
        ${generateXrayConfig} > /run/secrets/xray-config.json
        chown xray:xray /run/secrets/xray-config.json
        chmod 440 /run/secrets/xray-config.json
      '';

      path = [ pkgs.jq ];
    };

    # Ensure secrets directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.secretsDir} 0750 root root -"
      "d /run/secrets 0755 root root -"
    ];
  };
}
