{
  config,
  lib,
  rootPath,
  linkTree,
  pkgs,
  ...
}:
let
  cfg = config.kp2pml30;

  prompts = rootPath + "/agents/prompts";
  output-styles = rootPath + "/agents/claude/output-styles";
  # machine-local, unmanaged tail of the codex prompt; stitched in by reference so
  # it stays writable and out of the repo
  codexLocal = "${config.users.users.${cfg.username}.home}/.codex/LOCAL.md";
  # one blank line between sections, regardless of how each file ends

  text-to-prompt-part = path: t:
    let
      stripped = lib.removeSuffix "\n" t;
      splt = builtins.split "/" path;
      path-name = lib.removeSuffix ".md" (builtins.elemAt splt (builtins.length splt - 1));
    in if builtins.substring 0 3 stripped == "---"
    then stripped
    else "---\nname: ${path-name}\n---\n\n" + stripped;

  stitch =
    parts: lib.concatMapStringsSep "\n" (p: text-to-prompt-part p (builtins.readFile p)) parts + "\n";

  # herdr identifies agents by process name, which is codex-raw behind the nix
  # wrapper; HERDR_AGENT is its supported override
  codexWrapped = pkgs.codex.overrideAttrs (o: {
    nativeBuildInputs = (o.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postFixup = (o.postFixup or "") + ''
      wrapProgram $out/bin/codex --set HERDR_AGENT codex
    '';
  });
in
{
  config = lib.mkIf cfg.agent.enable {
    environment.systemPackages = with pkgs; [
      claude-code
      codexWrapped
      rtk
      code2prompt
      diffutils
      forgejo-cli # `fj`, gh for forgejo
      gawk
      gh
      gnused
      patch
      patchutils
      ripgrep
      fd
      yj
      yq
    ];

    home-manager.users.${cfg.username} =
      { lib, ... }:
      {
        home.file =
          linkTree ".claude/skills" (rootPath + "/agents/skills")
          // linkTree ".claude" (rootPath + "/agents/claude")
          // linkTree ".codex/skills" (rootPath + "/agents/skills")
          // {
            ".claude/CLAUDE.md".text = stitch [
              "${prompts}/PRELUDE.md"
              "${prompts}/CLAUDE.md"
            ];
            ".codex/AGENTS.md".text = stitch [ "${prompts}/PRELUDE.md" "${output-styles}/brief.md" ] + "\n@${codexLocal}\n";
          };

        # keep the import above from dangling on a machine that has no local notes yet
        home.activation.codexLocalPrompt = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          [ -e ${codexLocal} ] || run touch ${codexLocal}
        '';
      };
  };
}
