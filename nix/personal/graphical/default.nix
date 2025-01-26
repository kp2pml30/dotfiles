{ pkgs
, lib
, config
, ...
}:
let
	cfg = config.kp2pml30;
in {
	imports = [
		./x.nix
		./kitty.nix
		./vscode.nix

		./opera.nix
		./steam.nix
	];

	environment.systemPackages = with pkgs; [
		fira-code
		fira-code-nerdfont
	];
}
