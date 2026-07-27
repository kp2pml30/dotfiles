{
  config,
  lib,
  rootPath,
  pkgs,
  ...
}:
let
  cfg = config.kp2pml30;

  # per-file home.file entries for every file under `src`, rooted at `dest`,
  # so the target dirs stay writable (only managed files are symlinks).
  linkTree =
    dest: src:
    lib.listToAttrs (
      map (
        f:
        lib.nameValuePair
          # names are derived from store paths; strip context so they're
          # usable as attribute names (the `source` keeps the real path).
          (builtins.unsafeDiscardStringContext "${dest}/${lib.removePrefix "${toString src}/" (toString f)}")
          { source = f; }
      ) (lib.filesystem.listFilesRecursive src)
    );
in
{
  config = lib.mkIf cfg.agent {
    environment.systemPackages = with pkgs; [
      claude-code
      codex
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
      yj
      yq
    ];

    home-manager.users.${cfg.username}.home.file =
      linkTree ".claude/skills" (rootPath + "/agents/skills")
      // linkTree ".claude" (rootPath + "/agents/claude")
      // linkTree ".codex/skills" (rootPath + "/agents/skills");
  };
}
