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
		nixpkgs.overlays = [ inputs.claude-code.overlays.default ];
		programs = {
			tmux.enable = true;
			yazi.enable = true;
			htop.enable = true;
		};

		environment.systemPackages = with pkgs; [
			ncdu
			timewarrior
			p7zip
			claude-code
			lazydocker
		];

	};
}
