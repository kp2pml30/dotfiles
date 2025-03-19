{ pkgs
, config
, lib
, inputs
, rootPath
, ...
}:
let
	cfg = config.kp2pml30;
in {
	imports = [
		inputs.home-manager.nixosModules.home-manager
	];

	home-manager.useGlobalPkgs = true;
	home-manager.useUserPackages = true;
	home-manager.backupFileExtension = "bak";

	home-manager.users.${cfg.username} = { lib, ... }: {
		home = {
			stateVersion = "24.05";
			username = cfg.username;
			homeDirectory = "/home/${cfg.username}";
			packages = with pkgs; [
				jq
			];

			sessionVariables = {
				TERMINAL = "kitty";
			};

			activation = {
				makeWorkDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
					run mkdir -p ~/work/personal
					run mkdir -p ~/work/experiments
				'';
			};
		};

		nix.gc = {
			automatic = true;
			frequency = "weekly";
		};

		programs = {
			git = {
				enable = true;
				userName = cfg.username;
				userEmail = "kp2pml30@gmail.com";
				lfs.enable = true;
				extraConfig = {
					init.defaultBranch = "main";
				};
			};

			fish = {
				enable = true;
				shellInitLast = builtins.readFile (rootPath + "/home/.config/fish/minimal.fish");
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

			direnv = {
				enable = true;
				enableBashIntegration = true;
				#enableFishIntegration = lib.mkDefault true;
				nix-direnv.enable = true;
			};
		};

		dconf.settings = {
			"org/gnome/desktop/interface" = {
				color-scheme = "prefer-dark";
			};
		};

		systemd.user.sessionVariables = config.home-manager.users.${cfg.username}.home.sessionVariables;
	};
}
