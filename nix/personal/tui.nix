{ config
, pkgs
, inputs
, lib
, ...
}@args:
let
	cfg = config.kp2pml30;
in {
	config = {
		nixpkgs.overlays = lib.optionals cfg.claude [ inputs.claude-code.overlays.default ];
		programs = {
			tmux.enable = true;
			yazi.enable = true;
			htop.enable = true;
		};

		environment.systemPackages = with pkgs; [
			ncdu
			timewarrior
			p7zip
			lazydocker
		] ++ lib.optionals cfg.claude [
			claude-code
			gh
		];

		home-manager.users.${cfg.username}.xdg.desktopEntries = lib.mkIf cfg.xserver {
			htop = {
				name = "htop";
				comment = "Process monitor";
				exec = "kitty -e htop";
				terminal = false;
				categories = [ "Utility" "System" "Monitor" "X-TUI" ];
			};
			ncdu = {
				name = "ncdu";
				comment = "Disk usage analyzer";
				exec = "kitty -e ncdu";
				terminal = false;
				categories = [ "Utility" "System" "X-TUI" ];
			};
			lazydocker = {
				name = "lazydocker";
				comment = "Docker TUI";
				exec = "kitty -e lazydocker";
				terminal = false;
				categories = [ "Utility" "Development" "X-TUI" ];
			};
		};
	};
}
