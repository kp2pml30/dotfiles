{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30;

	loginServer = "https://wg.kp2pml30.moe";

	decryptPreauthKey = pkgs.writeShellScript "decrypt-headscale-preauth" ''
		set -euo pipefail

		source /var/lib/secrets/.env

		if [ -z "''${KP2_DOTFILES_SECRET_KEY:-}" ]; then
			echo "Error: KP2_DOTFILES_SECRET_KEY environment variable not set" >&2
			exit 1
		fi

		${pkgs.openssl}/bin/openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -base64 -d \
			-k "$KP2_DOTFILES_SECRET_KEY" -in "${./server/secrets.yaml}" \
			| ${pkgs.yq}/bin/yq --arg id "${cfg.headscale-client-id}" \
				'.HEADSCALE_NODE_KEYS[] | select(.id == $id) | .key' -r
	'';
in {
	options.kp2pml30.headscale-client = lib.mkEnableOption "";
	options.kp2pml30.headscale-client-id = lib.mkOption {
		type = lib.types.str;
		description = "Host identifier used to select the pre-auth key from HEADSCALE_NODE_KEYS";
	};

	config = lib.mkIf cfg.headscale-client {
		services.tailscale = {
			enable = true;
			openFirewall = true;
		};

		networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

		systemd.tmpfiles.rules = [
			"d /var/lib/secrets 0750 root root -"
		];

		# Enrolls the node against headscale on first boot (and re-enrolls if the
		# tailscaled state is wiped). Idempotent: bails out when the local backend
		# already reports a "Running" state with a matching login server.
		systemd.services.headscale-enroll = {
			description = "Enroll node with self-hosted headscale";
			wantedBy = [ "multi-user.target" ];
			after = [ "tailscaled.service" "network-online.target" ];
			wants = [ "tailscaled.service" "network-online.target" ];
			serviceConfig = {
				Type = "oneshot";
				User = "root";
				EnvironmentFile = "/var/lib/secrets/.env";
				RemainAfterExit = true;
			};
			path = [ pkgs.jq config.services.tailscale.package ];
			script = ''
				set -euo pipefail

				STATUS=$(tailscale status --json 2>/dev/null || echo '{}')
				BACKEND=$(echo "$STATUS" | jq -r '.BackendState // "NoState"')
				CURRENT=$(echo "$STATUS" | jq -r '.CurrentTailnet.ControlURL // ""')

				if [ "$BACKEND" = "Running" ] && [ "$CURRENT" = "${loginServer}" ]; then
					echo "Already enrolled with ${loginServer}; nothing to do."
					exit 0
				fi

				KEY=$(${decryptPreauthKey})
				if [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
					echo "No pre-auth key found for id=${cfg.headscale-client-id}" >&2
					exit 1
				fi

				# Peer-mesh only. We deliberately do NOT pass:
				#   --advertise-routes=...    (would expose this host's LAN to peers)
				#   --advertise-exit-node     (would let peers route Internet via us)
				#   --exit-node=...           (would send our Internet via a peer)
				# The tunnel carries traffic between tailnet members and nothing else.
				# --reset clears any of these flags left over from a previous run.
				tailscale up \
					--login-server="${loginServer}" \
					--authkey="$KEY" \
					--hostname="${cfg.headscale-client-id}" \
					--accept-dns=true \
					--accept-routes=false \
					--exit-node= \
					--reset
			'';
		};
	};
}
