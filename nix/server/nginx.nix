{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.server;
in lib.mkIf cfg.nginx {
	security.acme = {
		acceptTerms = true;
		defaults.email = "kp2pml30@gmail.com";
		certs."${cfg.hostname}" = {
			serverAliases = [ "*.${cfg.hostname}" ];
			webroot = "/var/lib/acme/.challenges";
			group = "nginx";
		};
	};

	services.nginx = {
		enable = true;

		virtualHosts."${cfg.hostname}" = {
			addSSL = true;
			enableACME = true;
			listen = [
				{ port = 80; }
			];
			locations."/.well-known/acme-challenge/" = {
				root = "/var/lib/acme/.challenges";
			};
			locations."/" = {
				return = 404;
			};
		};

		streamConfig = (builtins.readFile ./stream.nginx);
	};
}
