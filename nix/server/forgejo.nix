{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.server;
in lib.mkIf cfg.forgejo {
	services.forgejo = {
		enable = true;
		database.type = "postgres";
		lfs.enable = true;
		settings = {
			server = {
				DOMAIN = "git.${cfg.hostname}";
				ROOT_URL = "https://git.${cfg.hostname}/";
				HTTP_PORT = 8002;
			};
			service.DISABLE_REGISTRATION = true;
		};
	};
}
