{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.headscale-client;

	loginServer = "https://wg.kp2pml30.moe";

	preauthFile = "/run/secrets/headscale-preauth/${cfg.id}";
in {
	options.kp2pml30.headscale-client = {
		enable = lib.mkEnableOption "headscale tailnet client";
		id = lib.mkOption {
			type = lib.types.str;
			default = config.kp2pml30.short-hostname;
			description = "Host identifier; selects the encrypted preauth key at nix/secrets/data/headscale-preauth/<id>. Defaults to kp2pml30.short-hostname.";
		};
		ssh.enable = lib.mkEnableOption "tailscale SSH server on this node";
	};

	config = lib.mkIf cfg.enable {
		services.tailscale = {
			enable = true;
			openFirewall = true;
		};

		networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

		# Enrolls the node against headscale on first boot (and re-enrolls if the
		# tailscaled state is wiped). Idempotent: bails out when the local backend
		# already reports a "Running" state with a matching login server.
		systemd.services.headscale-enroll = {
			description = "Enroll node with self-hosted headscale";
			wantedBy = [ "multi-user.target" ];
			after = [ "tailscaled.service" "network-online.target" "decrypt-secrets.service" ];
			wants = [ "tailscaled.service" "network-online.target" ];
			requires = [ "decrypt-secrets.service" ];
			unitConfig.ConditionPathExists = preauthFile;
			serviceConfig = {
				Type = "oneshot";
				User = "root";
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

				KEY=$(tr -d '[:space:]' < ${preauthFile})
				if [ -z "$KEY" ]; then
					echo "No pre-auth key in ${preauthFile}" >&2
					exit 1
				fi

				# Peer-mesh only. We deliberately do NOT pass:
				#   --advertise-routes=...    (would expose this host's LAN to peers)
				#   --advertise-exit-node     (would let peers route Internet via us)
				#   --exit-node=...           (would send our Internet via a peer)
				# --accept-routes is required so the tailnet CIDR (custom, not the
				# default 100.64.0.0/10) gets installed as a kernel route via
				# tailscale0; without it the per-node IPs leak to the default route.
				# --reset clears any of these flags left over from a previous run.
				tailscale up \
					--login-server="${loginServer}" \
					--authkey="$KEY" \
					--hostname="${cfg.id}" \
					--accept-dns=true \
					--accept-routes=true \
					--ssh=${lib.boolToString cfg.ssh.enable} \
					--exit-node= \
					--reset
			'';
		};
	};
}
