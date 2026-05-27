{ pkgs, lib, config, ... }:
let
	dataDir = ./data;
	identity = "/var/lib/secrets/main";
in
{
	fileSystems."/run/secrets" = {
		device = "tmpfs";
		fsType = "tmpfs";
		options = [ "nosuid" "nodev" "noexec" "noswap" "size=128M" "mode=0700" "uid=0" "gid=0" ];
	};

	systemd.services.decrypt-secrets = {
		description = "Decrypt secrets to /run/secrets";
		wantedBy = [ "multi-user.target" ];
		after = [ "run-secrets.mount" ];
		requires = [ "run-secrets.mount" ];
		unitConfig.ConditionPathExists = identity;

		serviceConfig = {
			Type = "oneshot";
			RemainAfterExit = true;
			ProtectSystem = "strict";
			ReadWritePaths = [ "/run/secrets" ];
		};

		path = [ pkgs.age pkgs.coreutils pkgs.findutils ];

		script = ''
			set -u
			src=${dataDir}
			ok=0
			skip=0
			while IFS= read -r -d "" f; do
				case "$f" in *.recipients) continue ;; esac
				rel=''${f#"$src/"}
				out=/run/secrets/$rel
				install -d -m 0700 -o root -g root "$(dirname "$out")"
				if age -d -i ${identity} -o "$out".tmp "$f" 2>/dev/null; then
					chmod 0400 "$out".tmp
					mv "$out".tmp "$out"
					ok=$((ok + 1))
					echo "decrypted: $rel"
				else
					rm -f "$out".tmp
					skip=$((skip + 1))
					echo "skip: $rel (no matching key)"
				fi
			done < <(find "$src" -type f -print0)
			echo "decrypt-secrets: $ok decrypted, $skip skipped"
		'';
	};
}
