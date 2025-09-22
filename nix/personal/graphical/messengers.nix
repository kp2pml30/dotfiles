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
	discord-version = "0.0.160";
in lib.mkIf cfg.messengers.personal {
	users.users.${cfg.username}.packages = with pkgs; [
		discord-ptb
		#(discord-ptb.overrideAttrs(finalAttrs: previousAttrs: {
		#	src = fetchurl {
		#		url = "https://ptb.dl2.discordapp.net/apps/linux/${discord-version}/discord-ptb-${discord-version}.tar.gz";
		#		hash = lib.fakeHash;
		#	};
		#}))
		telegram-desktop
#		(pkgs.callPackage "${pkgs.path}/pkgs/by-name/si/signal-desktop/generic.nix" { } rec {
#			pname = "signal-desktop";
#			version = "7.65.0";
#
#			libdir = "opt/Signal";
#			bindir = libdir;
#			extractPkg = "dpkg-deb -x $downloadedFile $out";
#
#			url = "https://updates.signal.org/desktop/apt/pool/s/signal-desktop/signal-desktop_${version}_amd64.deb";
#			hash = lib.fakeHash;
#		})
	];
}
