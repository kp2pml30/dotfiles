{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
		nixos-wsl = {
			url = "github:nix-community/NixOS-WSL/main";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		home-manager = {
			url = "github:nix-community/home-manager/release-24.11";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		#vscode-server = {
		#	url = "github:nix-community/nixos-vscode-server";
		#	inputs.nixpkgs.follows = "nixpkgs";
		#};
	};

	outputs = inputs@{ self, nixpkgs, nixos-wsl, home-manager, ... }:
		let
			rootPath = self;
			additionalArgs = { inherit inputs rootPath; };
			lib = nixpkgs.lib;
		in
		{
			nixosConfigurations = {
				personal-laptop = nixpkgs.lib.nixosSystem {
					system = "x86_64-linux";
					modules = [
						{
							networking.hostName = "kp2pml30-personal-laptop";
							networking.hostId = "e31a5cc0";

							time.timeZone = "Asia/Yerevan";
						}

						./nix/hardware/ideapad.nix

						./nix/common.nix

						./nix/personal

						{
							kp2pml30 = {
								xserver = true;
								vscode = true;
								kitty = true;
								opera = true;
								steam = true;
							};
						}
					];
					specialArgs = additionalArgs;
				};
				personal-wsl = nixpkgs.lib.nixosSystem {
					system = "x86_64-linux";
					modules = [
						{
							networking.hostName = "kp2pml30-personal-wsl";
							networking.hostId = "e31a5cbf";
						}
						./nix/wsl.nix
						./nix/common.nix
						./nix/personal.nix
					];
					specialArgs = additionalArgs;
				};
			};
		};
}

# example
# + nix --extra-experimental-features 'nix-command flakes' build --out-link /tmp/nixos-rebuild.ydOEVb/nixos-rebuild '.#nixosConfigurations."wsl-amd64".config.system.build.nixos-rebuild' --show-trace
# ++ readlink -e /tmp/nixos-rebuild.ydOEVb/nixos-rebuild
# + p=/nix/store/rd18dwsifrcyghim695q18nhvyfykxxg-nixos-rebuild
# exec /nix/store/rd18dwsifrcyghim695q18nhvyfykxxg-nixos-rebuild/bin/nixos-rebuild switch --flake .#wsl-amd64
