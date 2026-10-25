{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kp2pml30;
  braveMcp = pkgs.callPackage ./brave-search-mcp { };
  yaml = pkgs.formats.yaml { };
  secretsDir = "/run/agent-secrets";
  braveKey = "${secretsDir}/brave";
  deepInfraKey = "${secretsDir}/deep-infra";

  dshUnwrapped = pkgs.callPackage ./dsh { };
  # llm-pi-ai only takes keys from the environment; a non-empty one already set wins
  dsh = pkgs.symlinkJoin {
    name = "dsh-with-keys";
    paths = [ dshUnwrapped ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in dsh dsh-tui; do
        wrapProgram $out/bin/$bin --run '
          if [ -z "''${DEEPINFRA_API_KEY-}" ] && [ -r ${deepInfraKey} ]; then
            export DEEPINFRA_API_KEY="$(< ${deepInfraKey})"
          fi'
      done
    '';
  };

  patch = [
    {
      id = "llm-pi-ai";
      # no openai-codex here: dsh-tui's `/auth login openai-codex` mounts that route
      # with its stored sign-in, and a route declared here would shadow it keyless
      config.providers = {
        deepinfra = {
          displayName = "DeepInfra";
          api = "openai-completions";
          baseURL = "https://api.deepinfra.com/v1/openai";
          apiKeyEnv = "DEEPINFRA_API_KEY";
          compat = {
            supportsDeveloperRole = false;
            maxTokensField = "max_tokens";
            thinkingFormat = "deepseek";
          };
          models =
            map
              (id: {
                inherit id;
                # DeepInfra's /models metadata; drives auto-compaction thresholds
                contextWindow = 1048576;
                reasoningEfforts = {
                  off = null;
                  high = "high";
                  max = "max";
                };
              })
              [
                "deepseek-ai/DeepSeek-V4-Pro"
                "deepseek-ai/DeepSeek-V4.1-Flash"
              ];
        };
      };
    }
    {
      insert = [
        {
          id = "self-compact";
          name = "@kp2pml30/dsh-plugins/self-compact";
        }
        # the presets mount the schedule_* tools; their host service only ships in the web bundle
        {
          id = "live-session-controller";
          name = "@kp2pml30/dsh-plugins/live-session-controller";
        }
        {
          id = "schedule";
          name = "@deepseek-ai/dsh-schedule";
        }
        {
          id = "mcp-brave";
          name = "@deepseek-ai/dsh-mcp-client";
          config = {
            serverName = "brave";
            transport = "stdio";
            command = lib.getExe braveMcp;
            env = {
              BRAVE_API_KEY_FILE = braveKey;
              BRAVE_MCP_ENABLED_TOOLS = "brave_web_search brave_news_search";
            };
          };
        }
      ];
    }
    {
      # native web_search needs a DeepSeek key, brave replaces it; preset rows only take preset-patch
      insert =
        map
          (preset: {
            id = "no-web-search-${preset}";
            name = "@deepseek-harness-tui/dsh-tui/preset-patch";
            config = {
              inherit preset;
              config.tool-web = {
                search = false;
                fetch = preset != "liangshen";
              };
            };
          })
          [
            "standard"
            "ptc"
            "cordis"
            "liangshen"
          ];
    }
  ];

  # the base default is deepseek-official, which needs a DeepSeek key
  headlessPatch = [
    {
      id = "agent-default-model";
      config = {
        provider = "deepinfra";
        model = "deepseek-ai/DeepSeek-V4-Pro";
        reasoningEffort = "high";
      };
    }
    # waits on agentPresets, which headless never provides
    {
      id = "self-compact";
      disabled = true;
    }
  ];

  # a bundle layer, so it stays out of other profiles and below in-app settings
  mkBundle =
    name: patch:
    pkgs.runCommand name { } ''
      mkdir $out
      cp ${yaml.generate "cordis.patch.yml" patch} $out/cordis.patch.yml
      cp ${
        pkgs.writeText "package.json" (
          builtins.toJSON {
            inherit name;
            private = true;
            dsh.bundle.patch = "./cordis.patch.yml";
          }
        )
      } $out/package.json
    '';
  bundles = lib.mapAttrs mkBundle {
    dsh-local-bundle = patch;
    dsh-headless-bundle = headlessPatch;
  };

  profileModules = pkgs.runCommand "dsh-profile-node-modules" { } ''
    mkdir $out
    shopt -s nullglob
    for f in ${dshUnwrapped}/lib/node_modules/* ${dshUnwrapped}/lib/node_modules/.[!.]*; do
      ln -s "$f" $out/
    done
    ${lib.concatMapAttrsStringSep "\n" (n: b: "ln -s ${b} $out/${n}") bundles}
  '';

  mkProfile = name: profileBundles: {
    ".dsh/profiles/${name}/package.json".text = builtins.toJSON {
      name = "dsh-profile-${name}";
      private = true;
      dsh.profile.bundles = profileBundles;
    };
    ".dsh/profiles/${name}/node_modules".source = profileModules;
  };
in
{
  config = lib.mkIf cfg.agent.enable {
    environment.systemPackages = [ dsh ];

    # /run/secrets is root-only
    systemd.services.agent-secrets = {
      description = "Expose agent API keys to ${cfg.username}";
      wantedBy = [ "multi-user.target" ];
      after = [ "decrypt-secrets.service" ];
      requires = [ "decrypt-secrets.service" ];
      partOf = [ "decrypt-secrets.service" ];
      unitConfig.ConditionPathIsDirectory = "/run/secrets/keys";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # recreated empty on every start, so removed or rotated keys leave no stale copy
        RuntimeDirectory = baseNameOf secretsDir;
        RuntimeDirectoryMode = "0700";
      };
      path = [ pkgs.coreutils ];
      script = ''
        chown ${cfg.username}:users ${secretsDir}
        for key in ${braveKey} ${deepInfraKey}; do
          src=/run/secrets/keys/$(basename "$key")
          [ -e "$src" ] || continue
          install -m 0400 -o ${cfg.username} -g users "$src" "$key"
        done
      '';
    };

    # store-managed, so in-app plugin add/toggle and dsh-tui's /update fail by design;
    # each profile's own cordis.patch.yml stays unmanaged, so in-app settings keep working
    home-manager.users.${cfg.username}.home.file =
      mkProfile "dsh-tui" [
        "@deepseek-ai/dsh-base"
        "@deepseek-harness-tui/dsh-tui"
        "dsh-local-bundle"
      ]
      // mkProfile "headless" [
        "@deepseek-ai/dsh-base"
        "@deepseek-ai/dsh-headless"
        "dsh-local-bundle"
        "dsh-headless-bundle"
      ]
      // {
        # `dsh tui`; dsh-tui hard-codes its own profile name, so this is only an alias
        ".dsh/profiles/tui".source =
          config.home-manager.users.${cfg.username}.lib.file.mkOutOfStoreSymlink
            "${config.users.users.${cfg.username}.home}/.dsh/profiles/dsh-tui";
      };
  };
}
