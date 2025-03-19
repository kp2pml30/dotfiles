{ config
, pkgs
, inputs
, lib
, ...
}@args:
let
	cfg = config.kp2pml30;
in {
	options.kp2pml30 = {
		username = lib.mkOption {
			type = lib.types.str;
			default = "kp2pml30";
		};
		xserver = lib.mkEnableOption "";
		vscode = lib.mkEnableOption "";
		kitty = lib.mkEnableOption "";
		opera = lib.mkEnableOption "";
		steam = lib.mkEnableOption "";
		messengers = {
			personal = lib.mkEnableOption "";
			work = lib.mkEnableOption "";
		};
	};

	imports = [
		./graphical
		./home.nix
		./user.nix
		./neovim.nix
	];

	config = {

		boot.supportedFilesystems = [ "zfs" ];
		boot.zfs.forceImportRoot = false;

		services.logind.extraConfig = ''
			HandlePowerKey=poweroff
			HandleLidSwitch=hibernate
		'';

		i18n.supportedLocales = [
			"C.UTF-8/UTF-8"
			"en_US.UTF-8/UTF-8"
			"ru_RU.UTF-8/UTF-8"
		];

		programs = {
			fish.enable = true;
			tmux.enable = true;
			yazi.enable = true;
		};

		environment.systemPackages = with pkgs; [
			fish
			fishPlugins.grc
			fishPlugins.bass

			python312 # needed for bass
			grc
		];

		nixpkgs.config.allowUnfreePredicate = pkg:
			builtins.elem (pkgs.lib.getName pkg) [
				"vscode"
				"steam"
				"steam-run"
				"steam-original"
				"steam-unwrapped"
				"nvidia-x11"
				"nvidia-settings"
				"nvidia-persistenced"
				"opera"
				"discord-ptb"
				"slack"
			];
	};
}
