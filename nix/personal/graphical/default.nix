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

		./steam.nix

		./messengers.nix
		./messengers-work.nix
	];

	xdg.portal = {
		enable = true;
		extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
	};
	services.flatpak.enable = true;
	systemd.services.flatpak-repo = {
		wantedBy = [ "multi-user.target" ];
		path = [ pkgs.flatpak ];
		script = ''
		flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
		'';
	};

	environment.systemPackages = with pkgs; [
		anytype
		flatpak
		gnome-software

		nodePackages.npm
		nodejs
	];

	fonts.enableDefaultPackages = true;
	fonts.packages = with pkgs; [
		noto-fonts
		noto-fonts-cjk-sans
		noto-fonts-cjk-sans

		fira-code
		fira-code-symbols

		nerd-fonts.fira-code
	];
}
