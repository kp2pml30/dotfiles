{ pkgs
, inputs
, ...
}@args:
{
	imports = [
		inputs.home-manager.nixosModules.home-manager
	];

	home-manager.useGlobalPkgs = true;
	home-manager.useUserPackages = true;
	home-manager.users.kp2pml30 = import ./personal/home.nix args;

	users.users.kp2pml30 = import ./personal/user.nix args;

	programs = {
		fish.enable = true;
		tmux.enable = true;
	};

	environment.systemPackages = with pkgs; [
		fish
		fishPlugins.grc
		grc

		fira-code
		nerd-fonts.fira-code
	];
}
