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
	networking.extraHosts = lib.concatStringsSep "\n" (
		groupToLines (groupByAttr "ip") ++ groupToLines (groupByAttr "ipv6")
	);
	system.stateVersion = "24.05";

	users.mutableUsers = false;

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

	nix.settings.experimental-features = [ "nix-command" "flakes" ];
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
}
