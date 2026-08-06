{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kp2pml30;
  # mcpjungle = pkgs.callPackage ./mcpjungle.nix { };
in
{
  config = lib.mkIf (cfg.agent.enable && cfg.agent.local) {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-vulkan;
      # pulled on service start, so embeddings keep working offline
      loadModels = [ "hf.co/Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0" ];
    };

   # environment.systemPackages = [ mcpjungle ];

    # per-user, so registered stdio servers inherit the session's environment
#    home-manager.users.${cfg.username}.systemd.user.services.mcpjungle = {
#      Unit.Description = "MCP gateway and registry";
#      Install.WantedBy = [ "default.target" ];
#      Service = {
#        ExecStart = "${lib.getExe mcpjungle} start --host 127.0.0.1 --sqlite-db-path %S/mcpjungle/mcpjungle.db";
#        StateDirectory = "mcpjungle";
#        Restart = "on-failure";
#      };
#    };
  };
}
