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
			AllowUsers = [ cfg.username "forgejo" ];
		};
	};

	services.fail2ban = {
		enable = true;
		maxretry = 5;
		bantime = "168h";
		bantime-increment = {
			enable = true;
			formula = "ban.Time * ban.Time";
		};
	};
}
