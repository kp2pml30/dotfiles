{ config
, pkgs
, inputs
, lib
, ...
}@args:
let
	cfg = config.kp2pml30;
in {
	config = {
		programs = {
			tmux.enable = true;
			yazi.enable = true;
			htop.enable = true;
		};
	};
}
