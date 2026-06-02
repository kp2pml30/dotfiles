{ config
, lib
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.hardware.wireless {
	home-manager.users.${cfg.username}.xdg.desktopEntries = lib.mkIf cfg.xserver {
		impala = {
			name = "impala (wifi)";
			comment = "Wi-Fi manager";
			exec = "kitty -e impala";
			terminal = false;
			categories = [ "Utility" "Network" "X-TUI" ];
		};
		bluetui = {
			name = "bluetui (bluetooth)";
			comment = "Bluetooth manager";
			exec = "kitty -e bluetui";
			terminal = false;
			categories = [ "Utility" "Network" "X-TUI" ];
		};
	};
}
