{ pkgs
, lib
, rootPath
, config
, system
, ...
}:
let
	cfg = config.kp2pml30;
	signal-pkgs = import (builtins.fetchTarball {
		url = "https://github.com/NixOS/nixpkgs/archive/71cbb752aa36854eb4a7deb3685b9789256d643c.tar.gz";
		sha256 = "10dnjv2c28bjgplyj6nbk2q9lng6f95jf75i5yh541zngrr8b2qg";
	}) {
		system = pkgs.system;
	};
in lib.mkIf cfg.messengers.personal {
	users.users.${cfg.username}.packages = with pkgs; [
		discord
		telegram-desktop
	] ++ [signal-pkgs.signal-desktop];
}
