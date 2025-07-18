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

	environment.systemPackages = [ pkgs.anytype ];

	fonts.enableDefaultFonts = true;
	fonts.packages = with pkgs; [
		noto-fonts
		noto-fonts-cjk-sans
		noto-fonts-cjk-sans

		fira-code
		fira-code-nerdfont
		fira-code-symbols

		(nerdfonts.override { fonts = [ "FiraCode" ]; })
	];
}
