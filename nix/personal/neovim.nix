{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
	fromGitHub = rev: repo: pkgs.vimUtils.buildVimPlugin {
		pname = "${lib.strings.sanitizeDerivationName repo}";
		version = rev;
		src = builtins.fetchGit {
			url = "https://github.com/${repo}.git";
			rev = rev;
		};
	};
	nvimConfig = builtins.readFile (rootPath + "/home/.config/nvim/base.vim");
in
{
	home-manager.users.${cfg.username}.programs.neovim = {
		enable = true;
		defaultEditor = true;

		withRuby = true;
		withPython3 = true;

		plugins = with pkgs.vimPlugins; [
			nvim-treesitter.withAllGrammars
			nvim-autopairs
			nerdtree
			tokyonight-nvim
			((fromGitHub "a4bef5b4fc1f064f2f673172252028eae18191c9" "romgrk/barbar.nvim").overrideAttrs (old: old // {
				doCheck = false;
			}))
			((fromGitHub "3587f57480b88e8009df7b36dc84e9c7ff8f2c49" "famiu/feline.nvim").overrideAttrs (old: old // {
				doCheck = false;
			}))
			(fromGitHub "d63c811337b2f75de52f16efee176695f31e7fbc" "timakro/vim-yadi")
			(fromGitHub "4fc505ac7bd7692824a142e96e5f529c133862f8" "nvim-tree/nvim-web-devicons")
		];

		extraConfig = nvimConfig;
	};
}
