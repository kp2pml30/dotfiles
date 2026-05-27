{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.server;
	ports = config.kp2pml30.server.ports;
in lib.mkIf cfg.headscale {
	services.headscale = {
		enable = true;
		address = "127.0.0.1";
		port = ports.headscale;
		settings = {
			server_url = "https://wg.${cfg.hostname}";
			metrics_listen_addr = "127.0.0.1:${toString ports.headscale-metrics}";
			grpc_listen_addr = "127.0.0.1:${toString ports.headscale-grpc}";

			prefixes = {
				v4 = "10.10.0.0/24";
				v6 = "fd7a:115c:a1e0::/48";
				allocation = "sequential";
			};

			dns = {
				magic_dns = true;
				# Must be disjoint from server_url's hostname (wg.${cfg.hostname});
				# headscale refuses to start otherwise. Resolved only via MagicDNS.
				base_domain = "ts.${cfg.hostname}";
				nameservers.global = [ "1.1.1.1" "9.9.9.9" ];
			};

			derp = {
				server = {
					enabled = true;
					region_id = 999;
					region_code = "kp2";
					region_name = "kp2 self-hosted";
					stun_listen_addr = "0.0.0.0:${toString ports.headscale-stun}";
				};
				# Also include the official DERP map as fallback.
				urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
				auto_update_enabled = true;
				update_frequency = "24h";
			};

			logtail.enabled = false;
		};
	};

	# Idempotently ensure the primary user exists. Pre-auth keys are minted
	# manually via `headscale preauthkeys create -u kp2pml30 --reusable` and
	# stored encrypted at nix/secrets/data/headscale-preauth/<id>.
	systemd.services.headscale-bootstrap = {
		description = "Ensure headscale users exist";
		wantedBy = [ "multi-user.target" ];
		after = [ "headscale.service" ];
		requires = [ "headscale.service" ];
		serviceConfig = {
			Type = "oneshot";
			User = "root";
		};
		script = ''
			${config.services.headscale.package}/bin/headscale users list --output json \
				| ${pkgs.jq}/bin/jq -e '.[] | select(.name == "${cfg.username}")' >/dev/null \
				|| ${config.services.headscale.package}/bin/headscale users create ${cfg.username}
		'';
	};
}
