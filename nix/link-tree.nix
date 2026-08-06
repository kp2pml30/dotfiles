lib:
# per-file home.file entries for every file under `src`, rooted at `dest`,
# so the target dirs stay writable (only managed files are symlinks).
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
)
