{ pkgs
, ...
}@args:
{
	home.stateVersion = "24.05";

	home = {
		username = "kp2pml30";
		homeDirectory = "/home/kp2pml30";
		packages = with pkgs; [
			starship
			jq
		];
	};

	nix.gc = {
		automatic = true;
		frequency = "weekly";
	};

	programs = {
		git = {
			enable = true;
			userName = "kp2pml30";
			userEmail = "kp2pml30@gmail.com";
			lfs.enable = true;
			extraConfig = {
				init.defaultBranch = "main";
			};
		};

		fish = {
			enable = true;
		};

		starship = {
			enable = true;
			settings = {
				add_newline = false;
				format = "$cmd_duration$username$hostname$git_branch$git_commit$git_state$git_status$directory$status\n$character";
				hostname.ssh_only = true;
				cmd_duration.format = "took [$duration]($style)\n";
			};
		};

		home-manager.enable = true;

		neovim = import ./neovim.nix args;
	};
}
