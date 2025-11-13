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

		plugins = with pkgs.vimPlugins; [
			nvim-treesitter.withAllGrammars
			nvim-autopairs
			nerdtree
			tokyonight-nvim
			barbar-nvim
			((fromGitHub "3587f57480b88e8009df7b36dc84e9c7ff8f2c49" "famiu/feline.nvim").overrideAttrs (old: {
				doCheck = false;
			}))
			(fromGitHub "d63c811337b2f75de52f16efee176695f31e7fbc" "timakro/vim-yadi")
			(fromGitHub "aafa5c187a15701a7299a392b907ec15d9a7075f" "nvim-tree/nvim-web-devicons")
		];

		extraConfig = nvimConfig;
	};
}
