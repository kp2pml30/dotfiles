{ pkgs
, config
, lib
, inputs
, user-groups-ids
, ...
}:
let
	cfg = config.kp2pml30;
in {
	nix.settings.trusted-users = [ cfg.username ];

	users.users.${cfg.username} = {
		isNormalUser = true;
		uid = user-groups-ids.uids.kp2pml30;
		extraGroups = [
			"wheel" # sudo
			"networkmanager"
			"dialout" "uucp" # esp32
			"docker"
		];
		shell = pkgs.fish;
		hashedPassword = "$6$UK6oHr2gPRYD4Rak$lgF.mYReC0jahNuI4kt0j/CsrajVzMprvp3HgjKwwsjYHU6/Ur9jfROXZbKhhpyCLRmnlCpWeRCbHEYO/jhIv/";
	};
}
