{  pkgs
, lib
, ...
}:
let
	ips = import ./server/ips.nix;
	groupByAttr = attr: lib.foldlAttrs (acc: _: v:
		acc // { ${v.${attr}} = (acc.${v.${attr}} or []) ++ [ v.full-address ]; }
	) {} ips.addresses;
	groupToLines = lib.mapAttrsToList (ip: domains: "${ip} ${lib.concatStringsSep " " domains}");
in
{
	imports = [ ./secrets ];

	options.kp2pml30.short-hostname = lib.mkOption {
		type = lib.types.str;
		description = "Short identifier for this host (e.g. mini, vdsina). Used as the default for tailscale id, encrypted-secret recipient id, etc.";
	};

	config = {
		networking.extraHosts = lib.concatStringsSep "\n" (
			groupToLines (groupByAttr "ip") ++ groupToLines (groupByAttr "ipv6")
		);
		system.stateVersion = "24.05";

		users.mutableUsers = false;

		services.openssh.settings = {
			PasswordAuthentication = lib.mkDefault false;
			KbdInteractiveAuthentication = lib.mkDefault false;
			PermitRootLogin = lib.mkDefault "no";

			# PQ-hybrid KEX only. Both algorithms mix in X25519 so the connection
			# is at least as strong as classical ECDH even if the PQ part breaks.
			# Requires OpenSSH >= 9.9 on the client (mlkem768) or >= 9.0 (sntrup761).
			KexAlgorithms = [
				"mlkem768x25519-sha256"
				"sntrup761x25519-sha512@openssh.com"
			];
		};

		console.keyMap = "us";

		nix.gc = {
			automatic = true;
			dates = "weekly";
		};

		boot = {
			tmp.useTmpfs = true;
		};

		systemd.services.nix-daemon = {
			environment.TMPDIR = "/var/tmp";
		};

		networking.firewall.enable = true;

		nix.settings = {
			experimental-features = [ "nix-command" "flakes" ];
			auto-optimise-store = true;
			sandbox = true;
			sandbox-fallback = false;
			# allow members of wheel to push store paths via SSH for
			# `nixos-rebuild --target-host`; root is implicitly trusted.
			trusted-users = [ "root" "@wheel" ];
		};
		environment.systemPackages = with pkgs; [
			curl
			neovim
			bash
			git

			zip unzip
			xz
			zstd
			gnutar

			diffutils
			file
			tree
			gnused
			gnugrep
			stow
			xxd

			killall
			gnupg
		];

		programs = {
			neovim.enable = true;
			neovim.defaultEditor = true;

			git = {
				enable = true;
				lfs.enable = true;
				config = {
					init.defaultBranch = "main";
				};
			};
		};
	};
}
