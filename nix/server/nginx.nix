{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.server;
	ports = config.kp2pml30.server.ports;
	acmeRoot = "/var/lib/acme/acme-challenge";
	pref = "kp2";
in lib.mkIf cfg.nginx {
	security.acme = {
		acceptTerms = true;
		maxConcurrentRenewals = 1;
		defaults.email = "kp2pml30@gmail.com";
		#defaults.server = "https://acme-staging-v02.api.letsencrypt.org/directory";
		certs."${cfg.hostname}" = {
			extraDomainNames = [ "pr.${cfg.hostname}" "www.${cfg.hostname}" "git.${cfg.hostname}" "backend.${cfg.hostname}" "dns.${cfg.hostname}" "cache.nix.${cfg.hostname}" "x.${cfg.hostname}" ];
			webroot = acmeRoot;
			group = "nginx";
		};
	};

	services.nginx = {
		enable = true;

		logError = "stderr debug";


		virtualHosts = {
			"git.${cfg.hostname}" = {
				enableACME = true;
				acmeRoot = acmeRoot;

				listen = [
					{ addr = "0.0.0.0"; port = 80; }
				];

				locations."/" = {
					proxyPass = "http://127.0.0.1:${toString ports.forgejo}";
				};
			};

			"backend.${cfg.hostname}" = {
				enableACME = true;
				acmeRoot = acmeRoot;

				listen = [
					{ addr = "0.0.0.0"; port = 80; }
				];

				locations."/" = {
					proxyPass = "http://127.0.0.1:${toString ports.backend}";
				};
			};

			"dns.${cfg.hostname}" = {
				enableACME = true;
				acmeRoot = acmeRoot;

				listen = [
					{ addr = "0.0.0.0"; port = 80; }
				];

				locations."/" = {
					proxyPass = "http://127.0.0.1:${toString ports.coredns-https}";
				};
			};

			"x.${cfg.hostname}" = {
				enableACME = true;
				acmeRoot = acmeRoot;

				listen = [
					{ addr = "0.0.0.0"; port = 80; }
				];

				locations."/" = {
					proxyPass = "https://www.lovelive-anime.jp";
					extraConfig = ''
						sub_filter                         $proxy_host $host;
						sub_filter_once                    off;

						proxy_set_header Host              $proxy_host;
						proxy_http_version                 1.1;
						proxy_cache_bypass                 $http_upgrade;
						proxy_ssl_server_name on;

						proxy_set_header Upgrade           $http_upgrade;
						proxy_set_header Connection        $connection_upgrade;
						proxy_set_header X-Real-IP         $proxy_protocol_addr;
						proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
						proxy_set_header X-Forwarded-Proto $scheme;
						proxy_set_header X-Forwarded-Host  $host;
						proxy_set_header X-Forwarded-Port  $server_port;

						proxy_connect_timeout              60s;
						proxy_send_timeout                 60s;
						proxy_read_timeout                 60s;

						resolver 1.1.1.1;
					'';
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
		} // (if cfg.xray then {
			# Xray fallback proxy servers
			"127.0.0.1:${toString ports.xray-fallback}" = {
				listen = [
					{ addr = "127.0.0.1"; port = ports.xray-fallback; proxyProtocol = true; }
				];

				locations."/" = {
					proxyPass = "https://www.lovelive-anime.jp";
					extraConfig = ''
						sub_filter                         $proxy_host $host;
						sub_filter_once                    off;

						proxy_set_header Host              $proxy_host;
						proxy_http_version                 1.1;
						proxy_cache_bypass                 $http_upgrade;
						proxy_ssl_server_name on;

						proxy_set_header Upgrade           $http_upgrade;
						proxy_set_header Connection        $connection_upgrade;
						proxy_set_header X-Real-IP         $proxy_protocol_addr;
						proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
						proxy_set_header X-Forwarded-Proto $scheme;
						proxy_set_header X-Forwarded-Host  $host;
						proxy_set_header X-Forwarded-Port  $server_port;

						proxy_connect_timeout              60s;
						proxy_send_timeout                 60s;
						proxy_read_timeout                 60s;

						resolver 1.1.1.1;
					'';
				};
			};

			"127.0.0.1:${toString ports.xray-websocket}" = {
				listen = [
					{ addr = "127.0.0.1"; port = ports.xray-websocket; proxyProtocol = true; }
				];

				locations."/" = {
					proxyPass = "https://www.lovelive-anime.jp";
					extraConfig = ''
						sub_filter                         $proxy_host $host;
						sub_filter_once                    off;

						proxy_set_header Host              $proxy_host;
						proxy_http_version                 1.1;
						proxy_cache_bypass                 $http_upgrade;
						proxy_ssl_server_name on;

						proxy_set_header Upgrade           $http_upgrade;
						proxy_set_header Connection        $connection_upgrade;
						proxy_set_header X-Real-IP         $proxy_protocol_addr;
						proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
						proxy_set_header X-Forwarded-Proto $scheme;
						proxy_set_header X-Forwarded-Host  $host;
						proxy_set_header X-Forwarded-Port  $server_port;

						proxy_connect_timeout              60s;
						proxy_send_timeout                 60s;
						proxy_read_timeout                 60s;

						resolver 1.1.1.1;
					'';
				};
			};
		} else {}) // (if cfg.nix-cache then {
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
