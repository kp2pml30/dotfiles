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
			stateVersion = "25.11";
			username = cfg.username;
			homeDirectory = "/home/${cfg.username}";
			packages = with pkgs; [
				jq
			];

			sessionVariables = {
				TERMINAL = "xterm-kitty";
				NPM_CONFIG_PREFIX = "$HOME/.local/share/npm-global";
			};

			activation = {
				makeWorkDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
					run mkdir -p ~/work/personal
					run mkdir -p ~/work/experiments
					run mkdir -p ~/.sock
				'';
			};
		};

		nix.gc = {
			automatic = true;
			dates = "weekly";
		};

		programs = {
			git = {
				enable = true;
				lfs.enable = true;
				settings = {
					user.name = cfg.username;
					user.email = "kp2pml30@gmail.com";
					init.defaultBranch = "main";
				};
			};

			fish = {
				enable = true;
				shellInitLast = builtins.readFile (rootPath + "/home/.config/fish/config.fish");
			};

			nushell = {
				enable = true;
				extraEnv = builtins.readFile (rootPath + "/home/.config/nushell/env.nu");
				extraConfig = builtins.readFile (rootPath + "/home/.config/nushell/config.nu");
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

		xdg.desktopEntries = lib.mkIf config.kp2pml30.xserver {
			yazi = {
				name = "Yazi";
				comment = "Terminal file manager";
				exec = "kitty -- yazi %u";
				terminal = false;
				mimeType = [ "inode/directory" ];
				categories = [ "System" "FileManager" ];
			};
			nvim = {
				name = "Neovim";
				comment = "Terminal text editor";
				exec = "kitty -- nvim %F";
				terminal = false;
				mimeType = [ "text/plain" ];
				categories = [ "Utility" "TextEditor" ];
			};
		};

		xdg.mimeApps = lib.mkIf config.kp2pml30.xserver (let
			mimeMap = desktop: types:
				builtins.listToAttrs (map (t: { name = t; value = [ desktop ]; }) types);
		in {
			enable = true;
			defaultApplications =
				{ "inode/directory" = [ "yazi.desktop" ]; }
				// mimeMap "nvim.desktop" [
					"text/plain" "text/html" "text/css" "text/xml" "text/markdown"
					"text/x-csrc" "text/x-chdr" "text/x-c++src" "text/x-c++hdr"
					"text/x-python" "text/x-shellscript" "text/x-makefile"
					"application/json" "application/xml" "application/x-yaml"
					"application/toml" "application/javascript" "application/x-shellscript"
					"application/x-nix"
				]
				// mimeMap "feh.desktop" [
					"image/png" "image/jpeg" "image/gif" "image/webp" "image/bmp" "image/svg+xml"
				]
				// mimeMap "vlc.desktop" [
					"video/mp4" "video/x-matroska" "video/webm" "video/x-msvideo"
					"video/quicktime" "video/x-flv"
				];
		});

		dconf.settings = lib.mkIf config.kp2pml30.xserver {
			"org/gnome/desktop/interface" = {
				color-scheme = "prefer-dark";
			};
		};

		systemd.user.sessionVariables = config.home-manager.users.${cfg.username}.home.sessionVariables;
	};
}
