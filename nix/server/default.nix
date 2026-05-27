{ config
, pkgs
, lib
, data
, ...
}:
let
	cfg = config.kp2pml30.server;
in {
	options.kp2pml30.server = {
		username = lib.mkOption {
			type = lib.types.str;
			default = "kp2pml30";
		};
		hostname = lib.mkOption {
			type = lib.types.str;
			default = null;
		};

		nginx = lib.mkEnableOption "";

		forgejo = lib.mkEnableOption "";

		dns = lib.mkEnableOption "";
		nix-cache = lib.mkEnableOption "";
		xray = lib.mkEnableOption "";
		headscale = lib.mkEnableOption "";

		sitePath = lib.mkOption {
			type = lib.types.str;
		};
	};

	imports =  [
		./ports.nix
		./ssh.nix
		./nginx.nix
		./boot.nix
		./site.nix
		./forgejo.nix
		./dns.nix
		./nix-cache.nix
		./xray.nix
		./headscale.nix
		./secrets.nix
		./firewall.nix
	];

	config = {
		users.groups.certreaders = { gid = data.gids.certreaders; };
		users.users.nginx.extraGroups = [ "certreaders" ];

		security.pam.sshAgentAuth.enable = true;

		users.users."${cfg.username}" = {
			isNormalUser = true;
			uid = data.uids.kp2pml30;
			openssh.authorizedKeys.keys = [
				data.ssh-keys.kp2pml30-personal-pc
			];
			extraGroups = [ "wheel" "networkmanager" "acme" ];
			hashedPassword = "$6$UK6oHr2gPRYD4Rak$lgF.mYReC0jahNuI4kt0j/CsrajVzMprvp3HgjKwwsjYHU6/Ur9jfROXZbKhhpyCLRmnlCpWeRCbHEYO/jhIv/";
		};
	};
}
