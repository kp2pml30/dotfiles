{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.server;
	acmeRoot = "/var/lib/acme/acme-challenge";
	pref = "kp2";
in lib.mkIf cfg.nginx {
	security.acme = {
		acceptTerms = true;
		maxConcurrentRenewals = 1;
		defaults.email = "kp2pml30@gmail.com";
		#defaults.server = "https://acme-staging-v02.api.letsencrypt.org/directory";
		certs."${cfg.hostname}" = {
			extraDomainNames = [ "pr.${cfg.hostname}" "www.${cfg.hostname}" "git.${cfg.hostname}" "backend.${cfg.hostname}" "dns.${cfg.hostname}" "cache.nix.${cfg.hostname}" ];
			webroot = acmeRoot;
			group = "nginx";
		};
	};

	services.nginx = {
		enable = true;

		virtualHosts = {
			"git.${cfg.hostname}" = {
				enableACME = true;
				acmeRoot = acmeRoot;

				listen = [
					{ addr = "0.0.0.0"; port = 80; }
				];

				locations."/" = {
					proxyPass = "http://127.0.0.1:8002";
				};
			};

			"backend.${cfg.hostname}" = {
				enableACME = true;
				acmeRoot = acmeRoot;

				listen = [
					{ addr = "0.0.0.0"; port = 80; }
				];

				locations."/" = {
					proxyPass = "http://127.0.0.1:8001";
				};
			};

			"dns.${cfg.hostname}" = {
				enableACME = true;
				acmeRoot = acmeRoot;

				listen = [
					{ addr = "0.0.0.0"; port = 80; }
				];

				locations."/" = {
					proxyPass = "http://127.0.0.1:8003";
				};
			};


			"${cfg.hostname}" = {
				# addSSL = true;
				# forceSSL = true;
				enableACME = true;
				acmeRoot = acmeRoot;

				listen = [
					{ addr = "0.0.0.0"; port = 80; }
				];

				locations."/" = {
					root = cfg.sitePath;
					tryFiles = "$uri $uri/ /index.html";
				};
			};
		} // (if cfg.nix-cache then {
			"cache.nix.${cfg.hostname}" = {
				enableACME = true;
				acmeRoot = acmeRoot;
				listen = [
					{ addr = "0.0.0.0"; port = 80; }
				];
				locations."/" = {
					proxyPass = "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
				};
			};
		} else {});

		streamConfig = (builtins.readFile ./stream.nginx);
	};
}
