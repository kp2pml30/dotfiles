{  pkgs
, ...
}:
{
	system.stateVersion = "24.05";

	users.mutableUsers = false;

	nix.gc = {
		automatic = true;
		dates = "weekly";
	};

	networking = {
		firewall = {
			enable = true;
			allowedTCPPorts = [ 80 443 ];
		};
	};

	nix.settings.experimental-features = [ "nix-command" "flakes" ];
	environment.systemPackages = with pkgs; [
		curl
		neovim
		bash
		git

		zip unzip
		xz
		zstd
		gnutar

		diffutils
		file
		tree
		gnused
		gnugrep
		stow

		killall
		gnupg
	];

	programs = {
		neovim.enable = true;
		neovim.defaultEditor = true;

		git = {
			enable = true;
			lfs.enable = true;
			config = {
				init.defaultBranch = "main";
			};
		};
	};
}
