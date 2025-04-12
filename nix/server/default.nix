{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30.server;
in {
	options.kp2pml30.server = {
		username = lib.mkOption {
			type = lib.types.str;
			default = "kp2pml30-serv";
		};
		hostname = lib.mkOption {
			type = lib.types.str;
			default = null;
		};

		nginx = lib.mkEnableOption "";

		forgejo = lib.mkEnableOption "";

		sitePath = lib.mkOption {
			type = lib.types.str;
		};
	};

	imports =  [
		./ssh.nix
		./nginx.nix
		./boot.nix
		./site.nix
		./forgejo.nix
	];

	config = {
		users.users."${cfg.username}" = {
			isNormalUser = true;
			openssh.authorizedKeys.keys = [
				"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2dRBDECmIuKt+2B2q9cmFudKga+EzbD4pCX6x3JNLB kp2pml30@kp2pml30-personal-pc"
			];
			extraGroups = [ "wheel" "networkmanager" "acme" ];
			hashedPassword = "$6$UK6oHr2gPRYD4Rak$lgF.mYReC0jahNuI4kt0j/CsrajVzMprvp3HgjKwwsjYHU6/Ur9jfROXZbKhhpyCLRmnlCpWeRCbHEYO/jhIv/";
		};
	};
}
