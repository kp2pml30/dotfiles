{ config
, pkgs
, lib
, self
, nixpkgs
, kp2pml30-moe
, system
, ...
}@args:
let
	cfg = config.kp2pml30.server;
	backend = kp2pml30-moe.packages.${system}.kp2pml30-moe-backend;
	frontend = kp2pml30-moe.packages.${system}.kp2pml30-moe-frontend;
in lib.mkIf cfg.nginx {
	environment.systemPackages = [
		frontend
	];
	kp2pml30.server.sitePath = frontend.outPath;

	users.users.kp2pml30-moe-backend = {
		home = "/home/kp2pml30-moe-backend";
		isNormalUser = true;

		packages = [
			backend
			pkgs.bash
		];
	};

	systemd.services.kp2pml30-moe-backend-service = {
		enable = true;

		after = [ "network-online.target" ];
		wantedBy = [ "multi-user.target" ];


		serviceConfig = {
			User = "kp2pml30-moe-backend";

			ProtectSystem = "full";
			ProtectHostname = "true";
			ProtectKernelTunables = "true";
			ProtectControlGroups = "true";

			Restart = "on-failure";
			RestartSec = "3";

			ExecStart = ''${pkgs.bash}/bin/bash -c "source /home/kp2pml30-moe-backend/env.sh && touch /home/kp2pml30-moe-backend/db.json && ${backend}/bin/kp2pml30-moe-backend --port 8001 --moderated-path /home/kp2pml30-moe-backend/chatbox-db.json"'';
		};
	};
}
