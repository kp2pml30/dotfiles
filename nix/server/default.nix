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
	};

	imports =  [
		./ssh.nix
		./nginx.nix
		./boot.nix
	];

	config = {
		users.users."${cfg.username}" = {
			isNormalUser = true;
			openssh.authorizedKeys.keys = [
				"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCmc+wSjdvbyiFmB55r1ilegor533eo7hsE62z+pXCu0YIaVZwUoRe0Sqj0GoMzfn80jXubNmQgV+Wk8byz/xAsZ4R9Y/PFVuZYA/uDRAQ0TXpqxBSCH2CHkwioolg6q+sMXdUJTvvKkCpluXVk8o9ZN+5+rBhc2xAeZw2FDbz+u2HHYN8zCXFB3MPPJNG9CscBQirBgOkhg0ASCJ2rahaAJVaBosS7DD6S6iEip8bGgwByuWJl0oZr9cdJHkQDl2AMdNZrxoPcLqItCk5Mz9ssxTcK0lj/xIBXqLNMe4RPUJeWOOMNexeKRbzJEaF+G3Pfboqqeg7UPM6/9h9CXW9cyY/DXEj2pQmEi2jYWdTpx/ViCg83/rLboGyiyAuE6AWGte8r5YqYKuFEB0ixswENlH0s4TXEmouimRRkypzT4KAJ/ObPLsnGAkbzbLcsPCQUQSywQ8TGo3b72gNWTKjn9PeqBZkzgU9AXtxN1hCmKAX+/KwnGUSqyDz2YRhcO1E= kp2pml30@r3vdy2b10vv-pc"
			];
			extraGroups = [ "wheel" "networkmanager" "acme" ];
			hashedPassword = "$6$UK6oHr2gPRYD4Rak$lgF.mYReC0jahNuI4kt0j/CsrajVzMprvp3HgjKwwsjYHU6/Ur9jfROXZbKhhpyCLRmnlCpWeRCbHEYO/jhIv/";
		};
	};
}
