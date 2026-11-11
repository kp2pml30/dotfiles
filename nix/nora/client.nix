{
  config,
  options,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kp2pml30.nora-client;
  toml = pkgs.formats.toml { };
  host = lib.head (lib.splitString ":" (lib.removePrefix "http://" cfg.url));

  cargoConfig = toml.generate "cargo-config.toml" {
    source = {
      crates-io.replace-with = "nora";
      nora.registry = "sparse+${cfg.url}/cargo/index/";
    };
  };
in
{
  options.kp2pml30.nora-client = {
    enable = lib.mkEnableOption "fetching packages through nora with cargo, go, pip and pnpm";
    url = lib.mkOption {
      type = lib.types.str;
      default = (import ./common.nix).url;
    };
    cargoUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.optional (options ? home-manager) config.kp2pml30.username;
      description = "Users whose ~/.cargo/config.toml points at nora; needs home-manager";
    };
  };

  config = lib.mkIf cfg.enable (
    {
      # Only tools that keep the registry URL out of lockfiles (not npm, bun, uv, poetry),
      # configured system-wide so projects and users still override it
      environment.sessionVariables.pnpm_config_registry = "${cfg.url}/npm/";
      environment.etc."pip.conf".text = ''
        [global]
        index-url = ${cfg.url}/simple/
        # pip ignores plain-http indexes otherwise
        trusted-host = ${host}
      '';
      # `|` falls back on any error, so go keeps working while nora is down
      environment.sessionVariables.GOPROXY = "${cfg.url}/go|https://proxy.golang.org|direct";
    }
    # Cargo has neither a system config nor env vars for [source], so it is per user
    // lib.optionalAttrs (options ? home-manager) {
      home-manager.users = lib.genAttrs cfg.cargoUsers (_: {
        home.file.".cargo/config.toml".source = cargoConfig;
      });
    }
  );
}
