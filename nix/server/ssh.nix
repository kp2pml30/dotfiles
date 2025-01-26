{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.server;
in {
	services.openssh = {
		enable = true;
		ports = [ 22 ];
		openFirewall = true;
		settings = {
			PasswordAuthentication = false;
			KbdInteractiveAuthentication = false;
			PermitRootLogin = lib.mkForce "no";
			AllowUsers = [ cfg.username ];
		};
	};
}
