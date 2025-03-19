{ pkgs
, lib
, rootPath
, config
, system
, ...
}:
let
	cfg = config.kp2pml30;
	signalSuffix = if system == "x86_64-linux" then "amd64" else "arm64";
in lib.mkIf cfg.messengers.personal {
	users.users.${cfg.username}.packages = with pkgs; [
		discord-ptb
		telegram-desktop
		(pkgs.callPackage "${toString pkgs.path}/pkgs/by-name/si/signal-desktop/generic.nix" {} rec {
			pname = "signal-desktop";
			dir = "Signal";
			version = "7.46.0";
			url = "https://updates.signal.org/desktop/apt/pool/s/signal-desktop/signal-desktop_${version}_${signalSuffix}.deb";
			hash = "sha256-HbmyivfhvZfXdtcL/Cjzl4v0Ck/fJCD517iTjIeidgc=";
		})
	];
}
