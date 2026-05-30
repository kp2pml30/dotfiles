{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.hardware.audio {
	security.rtkit.enable = true;
	services.pipewire = {
		enable = true;
		alsa.enable = true;
		alsa.support32Bit = true;
		pulse.enable = true;
	};
	environment.systemPackages = with pkgs; [
		alsa-utils
		acpid
		pulseaudio
		pulsemixer
	];

	home-manager.users.${cfg.username}.xdg.desktopEntries = lib.mkIf cfg.xserver {
		pulsemixer = {
			name = "pulsemixer";
			comment = "Audio mixer";
			exec = "kitty -e pulsemixer";
			terminal = false;
			categories = [ "Utility" "AudioVideo" "Audio" "X-TUI" ];
		};
	};
}
