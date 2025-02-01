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

		./messengers.nix
		./messengers-work.nix
	];

	fonts.packages = with pkgs; [
		fira-code
		fira-code-nerdfont
		fira-code-symbols

		(nerdfonts.override { fonts = [ "FiraCode" ]; })
	];
}
