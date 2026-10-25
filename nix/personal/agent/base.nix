{
  config,
  lib,
  inputs,
  rootPath,
  linkTree,
  pkgs,
  ...
}:
let
  cfg = config.kp2pml30;

  prompts = rootPath + "/agents/prompts";
  output-styles = rootPath + "/agents/claude/output-styles";
  # machine-local, unmanaged tail of the ChatGPT desktop prompt; stitched in by reference so
  # it stays writable and out of the repo
  codexLocal = "${config.users.users.${cfg.username}.home}/.codex/LOCAL.md";

  text-to-prompt-part =
    path: t:
    let
      stripped = lib.removeSuffix "\n" t;
      splt = builtins.split "/" path;
      path-name = lib.removeSuffix ".md" (builtins.elemAt splt (builtins.length splt - 1));
    in
    if builtins.substring 0 3 stripped == "---" then
      stripped
    else
      "---\nname: ${path-name}\n---\n\n" + stripped;

  # one blank line between sections, regardless of how each file ends
  stitch =
    parts: lib.concatMapStringsSep "\n" (p: text-to-prompt-part p (builtins.readFile p)) parts + "\n";
in
{
  config = lib.mkIf cfg.agent.enable {
    environment.systemPackages = with pkgs; [
      claude-code
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
      socat # dsh-tui's inject sockets
      fd
      yj
      yq
    ];

    home-manager.users.${cfg.username} =
      { lib, ... }:
      {
        imports = [ inputs.agent-skills.homeManagerModules.default ];

        programs.agent-skills = {
          enable = true;
          sources = {
            gh-stack = {
              path = inputs.gh-stack;
              subdir = "skills";
            };
            # herdr's own input, so the skill matches the installed binary
            herdr = {
              path = inputs.herdr;
              subdir = "skills";
            };
          };
          skills.enable = [
            "gh-stack"
            "herdr"
          ];
          # `link` adds per-skill entries, leaving linkTree and unmanaged skills alone
          targets = {
            claude = {
              enable = true;
              dest = ".claude/skills";
              structure = "link";
            };
            # ChatGPT desktop is the Codex app and reads ~/.codex
            codex = {
              enable = cfg.agent.chatgpt;
              dest = ".codex/skills";
              structure = "link";
            };
            # shared root, read by dsh
            agents = {
              enable = true;
              dest = ".agents/skills";
              structure = "link";
            };
          };
        };

        home.file =
          linkTree ".claude/skills" (rootPath + "/agents/skills")
          // linkTree ".claude" (rootPath + "/agents/claude")
          // linkTree ".agents/skills" (rootPath + "/agents/skills")
          // {
            ".claude/CLAUDE.md".text = stitch [
              "${prompts}/PRELUDE.md"
              "${prompts}/CLAUDE.md"
            ];
            # dsh's user-global prompt; ~/.agents/AGENTS.md would risk ChatGPT desktop loading it too
            ".dsh/AGENTS.md".text = stitch [
              "${prompts}/PRELUDE.md"
              "${output-styles}/brief.md"
            ];
          }
          // lib.optionalAttrs cfg.agent.chatgpt (
            linkTree ".codex/skills" (rootPath + "/agents/skills")
            // {
              ".codex/AGENTS.md".text =
                stitch [
                  "${prompts}/PRELUDE.md"
                  "${output-styles}/brief.md"
                ]
                + "\n@${codexLocal}\n";
            }
          );

        # keep the import above from dangling on a machine that has no local notes yet
        home.activation.codexLocalPrompt = lib.mkIf cfg.agent.chatgpt (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            [ -e ${codexLocal} ] || run touch ${codexLocal}
          ''
        );
      };
  };
}
