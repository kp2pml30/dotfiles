{
  config,
  ...
}:
let
  cfg = config.kp2pml30;
in
{
  home-manager.users.${cfg.username}.programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = cfg.username;
      user.email = "kp2pml30@gmail.com";
      init.defaultBranch = "main";

      push = {
        autoSetupRemote = true;
        default = "simple";
      };
      pull.rebase = true;
      fetch.prune = true;
      rebase = {
        autoStash = true;
        autoSquash = true;
      };
      branch.sort = "-committerdate";
      # replay conflict resolutions when the same branch is rebased again
      rerere.enabled = true;
    };
  };
}
