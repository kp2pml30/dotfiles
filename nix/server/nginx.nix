{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.server;
	acmeRoot = "/var/lib/acme/acme-challenge";
in lib.mkIf cfg.nginx {
	security.acme = {
		acceptTerms = true;
		maxConcurrentRenewals = 1;
		defaults.email = "kp2pml30@gmail.com";
		#defaults.server = "https://acme-staging-v02.api.letsencrypt.org/directory";
		certs."${cfg.hostname}" = {
			extraDomainNames = [ "pr.${cfg.hostname}" "www.${cfg.hostname}" ];
			webroot = acmeRoot;
			group = "nginx";
		};
	};

	services.nginx = {
		enable = true;

		virtualHosts."${cfg.hostname}" = {
			addSSL = true;
			# forceSSL = true;
			enableACME = true;
			acmeRoot = acmeRoot;

			listen = [
				{ addr = "0.0.0.0"; port = 80; }
				# { addr = "0.0.0.0"; port = 444; ssl = true; }
			];

			locations."/" = {
				root = cfg.sitePath;
				tryFiles = "$uri $uri/ /index.html";
			};
		};

		streamConfig = (builtins.readFile ./stream.nginx);
	};
}
