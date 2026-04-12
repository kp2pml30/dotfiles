{ pkgs, lib, ... }:
{
	users.mutableUsers = false;

	users.users.claude = {
		isNormalUser = true;
		extraGroups = [ "wheel" ];
		shell = pkgs.fish;
		hashedPassword = "";
	};

	users.users.root.hashedPassword = "";

	security.sudo.wheelNeedsPassword = false;

	programs.fish.enable = true;

	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "yes";
			PermitEmptyPasswords = "yes";
		};
	};

	networking.firewall.allowedTCPPorts = [ 22 ];

	nix.settings.trusted-users = [ "root" "claude" ];
}
