{
  config,
  pkgs,
  lib,
  inputs,
  data,
  ...
}:
let
  ya = inputs.ya-coder.packages.${pkgs.stdenv.hostPlatform.system}.default;
  braveMcp = pkgs.callPackage ../personal/agent/brave-search-mcp { };
  toml = pkgs.formats.toml { };

  user = "ya-coder";
  stateDir = "/var/lib/${user}";
  configDir = "${stateDir}/.config/ya";
  authFile = "${stateDir}/.cache/ya-coder/auth.json";
  harnessRoot = "${stateDir}/harness";
  socket = "/run/${user}/harness.sock";
  tailnet = "10.10.0.0/24,fd7a:115c:a1e0::/48";

  # Scopes must match the app's manifest; null disables Slack
  slack = {
    clientId = "6842340281088.12542941881249";
    scopes = [
      "search:read.public"
      "search:read.private"
      "search:read.mpim"
      "search:read.im"
      "search:read.users"
      "channels:history"
      "groups:history"
      "mpim:history"
      "im:history"
      "channels:read"
      "groups:read"
      "mpim:read"
      "im:read"
      "users:read"
      "chat:write"
    ];
  };

  # Tokens are mapped in secrets below
  bearerServers = {
    linear = "https://mcp.linear.app/mcp";
    github = "https://api.githubcopilot.com/mcp/";
  };
  servers = lib.attrNames bearerServers ++ lib.optional (slack != null) "slack" ++ [ "brave" ];

  # auth.json org -> path under nix/secrets/data; only secrets present in the flake are loaded
  secrets = lib.filterAttrs (_: path: builtins.pathExists (../secrets/data + "/${path}")) {
    linear = "keys/genlayer-linear";
    github = "keys/personal-github";
    slack-app-secret = "keys/genlayer-slack";
    brave = "keys/brave";
  };

  writerGroups = map (server: "${server}-writer") servers;

  # 1 SSH key per client: the key, not the client, selects the account
  clients = {
    claude = {
      id = "019a6000-0000-7000-8000-000000000001";
      key = data.ssh-keys.ya-coder-claude;
      groups = writerGroups;
    };
    deep-seek = {
      id = "019a6000-0000-7000-8000-000000000002";
      key = data.ssh-keys.ya-coder-deep-seek;
      # Brave's searches have no readOnlyHint, so they are suggested for its writer group
      groups = servers ++ [ "brave-writer" ];
    };
  };

  harnessConfig = toml.generate "config.toml" {
    mcp_servers =
      lib.mapAttrs (_: url: { inherit url; }) bearerServers
      // {
        brave = {
          command = lib.getExe braveMcp;
          env = {
            BRAVE_API_KEY_FILE = "/run/credentials/ya-coder.service/brave";
            BRAVE_MCP_ENABLED_TOOLS = "brave_web_search brave_news_search";
          };
        };
      }
      // lib.optionalAttrs (slack != null) {
        slack = {
          url = "https://mcp.slack.com/mcp";
          oauth = {
            client_id = slack.clientId;
            client_secret_key = "slack-app-secret";
            redirect_uri = "https://kp2pml30.moe/slack/callback";
            inherit (slack) scopes;
          };
        };
      };
  };

  accountsConfig = toml.generate "accounts.toml" {
    accounts =
      lib.mapAttrsToList (name: client: {
        inherit name;
        inherit (client) id groups;
        kind.external.adapter = "tui";
      }) clients
      ++ [
        # hooks hands classified mail over as this one
        {
          name = "mailer";
          id = "019a6000-0000-7000-8000-000000000003";
          groups = [ ];
          kind.external.adapter = "tui";
        }
      ];
    groups = lib.concatMap (server: [
      { name = server; }
      {
        name = "${server}-writer";
        includes = [ server ];
      }
    ]) servers;
  };

  cli = pkgs.writeShellScript "ya-coder-cli" ''
    cd ${stateDir}
    export YA_CODER_PROJECT_DIR=${harnessRoot}
    exec ${ya}/bin/ya coder --socket ${socket} "$@"
  '';

  # Only systemd starts the harness: a proxy-spawned one would hold the trace lock
  proxy = pkgs.writeShellScript "ya-coder-mcp" ''
    export YA_CODER_HARNESS_BIN=${pkgs.coreutils}/bin/false
    exec ${cli} mcp --as "$1"
  '';

  ctl = pkgs.writeShellScriptBin "ya-coder-ctl" ''
    exec sudo -H -u ${user} ${cli} "$@"
  '';
in
{
  assertions = [
    {
      assertion =
        let
          keys = lib.catAttrs "key" (lib.attrValues clients);
        in
        lib.length (lib.unique keys) == lib.length keys;
      message = "ya-coder: clients must not share an SSH key";
    }
  ];

  users.users.${user} = {
    isSystemUser = true;
    uid = data.uids.${user};
    group = user;
    home = stateDir;
    # sshd runs forced commands through the login shell
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = lib.mapAttrsToList (
      name: client: ''from="${tailnet}",command="${proxy} ${name}",restrict ${client.key}''
    ) clients;
  };

  users.groups.${user}.gid = data.gids.${user};

  services.openssh.settings.AllowUsers = [ user ];
  # This user's home is writable by its agents; a key there would skip the forced command
  services.openssh.extraConfig = ''
    Match User ${user}
      AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u
  '';

  environment.systemPackages = [ ctl ];

  systemd.services.ya-coder = {
    description = "ya coder harness";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "decrypt-secrets.service"
    ];
    requires = [ "decrypt-secrets.service" ];
    partOf = [ "decrypt-secrets.service" ];

    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.jq
      pkgs.util-linux
    ];

    # mcp-tools.toml is written beside these, so the directory stays mutable.
    # auth.json also holds OAuth tokens, so entries are merged, not replaced
    preStart = ''
      umask 077
      mkdir -p ${configDir} ${dirOf authFile}
      ln -sfn ${harnessConfig} ${configDir}/config.toml
      ln -sfn ${accountsConfig} ${configDir}/accounts.toml

      entries='[]'
      add() {
        file=$CREDENTIALS_DIRECTORY/$1
        if [ ! -e "$file" ]; then
          echo "ya-coder: no secret for $1" >&2
          return 0
        fi
        entries=$(jq -c --arg org "$1" --arg field "$2" --rawfile token "$file" \
          '. + [{provider: "mcp", org: $org, ($field): ($token | gsub("\\s"; ""))}]' <<<"$entries")
      }
      ${lib.concatMapStrings (server: ''
        add ${server} bearer_token
      '') (lib.attrNames bearerServers)}
      add slack-app-secret access_token

      exec 9> ${authFile}.lock
      flock 9
      [ -e ${authFile} ] || echo '[]' > ${authFile}
      # Tokens go through stdin, never argv
      jq -s --argjson managed '${
        builtins.toJSON (lib.attrNames bearerServers ++ [ "slack-app-secret" ])
      }' \
        '(.[0] | map(select(.provider != "mcp" or (.org | IN($managed[]) | not)))) + .[1]' \
        ${authFile} - <<<"$entries" > ${authFile}.tmp
      mv ${authFile}.tmp ${authFile}
    '';

    serviceConfig = {
      User = user;
      Group = user;
      ExecStart = lib.escapeShellArgs [
        "${ya}/bin/ya-coder-harness"
        "serve"
        "--root"
        harnessRoot
        "--config"
        configDir
        "--workdir"
        stateDir
        "--socket"
        socket
        # Group members (hooks) reach the socket, and may claim any TUI account on it
        "--socket-mode"
        "0660"
      ];
      WorkingDirectory = stateDir;
      LoadCredential = lib.mapAttrsToList (name: path: "${name}:/run/secrets/${path}") secrets;
      StateDirectory = user;
      StateDirectoryMode = "0700";
      RuntimeDirectory = user;
      RuntimeDirectoryMode = "0750";
      Restart = "on-failure";
      RestartSec = 5;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };
}
