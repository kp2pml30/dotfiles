{ pkgs
, config
, lib
, inputs
, ...
}:
let
	cfg = config.kp2pml30;
in {
	users.users.${cfg.username} = {
		isNormalUser = true;
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
