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
	];

	home-manager.users.${cfg.username} = {
		home.file.".config/awesome/rc.lua" = { source = rootPath + "/home/.config/awesome/rc.lua"; };
		programs.rofi = {
			enable = true;
		};
	};
}
