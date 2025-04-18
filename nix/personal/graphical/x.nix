{ pkgs
, config
, lib
, rootPath
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.xserver {
	services.displayManager.ly.enable = true;
	services.libinput.enable = true;
	services.xserver = {
		enable = true;
		displayManager.startx.enable = true;
		xkb = {
			layout = "us,ru";
			variant = ",";
			options = "grp:win_space_toggle";
		};
		windowManager.awesome = {
			enable = true;
			luaModules = with pkgs.luaPackages; [
				luarocks
				luadbi-mysql
			];
		};
		excludePackages = lib.optionals (!cfg.kitty) [
			pkgs.xterm
		];
	};

	environment.systemPackages = with pkgs; [
		xclip
		brightnessctl
		arandr
		libnotify
		xfce.xfce4-screenshooter
	];

	programs.dconf.enable = true;

	users.users.${cfg.username} = {
		packages = with pkgs; [
			rofimoji
		];
	};

	home-manager.users.${cfg.username} = {
		programs.rofi = {
			enable = true;
			theme = "simple-tokyonight";
			location = "center";
		};
		home.file.".config/rofi/simple-tokyonight.rasi" = { source = rootPath + "/home/.config/rofi/simple-tokyonight.rasi"; };

		home.file.".config/awesome/rc.lua" = { source = rootPath + "/home/.config/awesome/rc.lua"; };
		home.file.".config/awesome/theme.lua" = { source = rootPath + "/home/.config/awesome/theme.lua"; };
		home.file.".config/awesome/deficient" = {
			source = builtins.fetchGit {
				url = "https://github.com/deficient/deficient.git";
				rev = "22ad2bea198f0c231afac0b7197d9b4eb6d80da3";
			};
			recursive = true;
		};
	};
}
