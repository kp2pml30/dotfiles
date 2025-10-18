{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.server;
	ports = config.kp2pml30.server.ports;
in lib.mkIf cfg.forgejo {
	services.forgejo = {
		enable = true;
		database.type = "postgres";
		lfs.enable = true;
		settings = {
			server = {
				DOMAIN = "git.${cfg.hostname}";
				ROOT_URL = "https://git.${cfg.hostname}/";
				HTTP_PORT = ports.forgejo;
			};
			service.DISABLE_REGISTRATION = true;
		};
	};
}
