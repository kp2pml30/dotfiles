{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
		nixos-wsl = {
			url = "github:nix-community/NixOS-WSL/main";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		home-manager = {
			url = "github:nix-community/home-manager/release-25.05";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		nixos-generators = {
			url = "github:nix-community/nixos-generators";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		#vscode-server = {
		#	url = "github:nix-community/nixos-vscode-server";
		#	inputs.nixpkgs.follows = "nixpkgs";
		#};

		kp2pml30-moe = {
			url = "github:kp2pml30/kp2pml30.github.io/c70b7cc290dc4ca341d791fe952ea5e5e2e36e1b";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs@{ self, nixpkgs, nixos-wsl, home-manager, nixos-generators, kp2pml30-moe, ... }:
		let
			rootPath = self;
			additionalArgs = { inherit inputs rootPath; };
			lib = nixpkgs.lib;
		in
		{
			packages.x86_64-linux.docker-nix-node = import ./nix/docker-images/nix-node.nix {
				pkgs = import nixpkgs { system = "x86_64-linux"; };
				inherit lib;
				rootPath = self;
			};

			nixosConfigurations = {
				server = nixpkgs.lib.nixosSystem {
					system = "x86_64-linux";

					modules = [
						{
							networking.hostId = "e31a5cc1";
							time.timeZone = "Asia/Yerevan";

							kp2pml30.server = {
								hostname = "kp2pml30.moe";
								nginx = true;
								forgejo = true;
								nix-cache = true;
								xray = true;
							};
						}

						./nix/common.nix

						./nix/server

						./nix/hardware/server.nix

						nixos-generators.nixosModules.all-formats
					];

					specialArgs = { inherit kp2pml30-moe; system = "x86_64-linux"; };
				};

				personal-pc = nixpkgs.lib.nixosSystem rec {
					system = "x86_64-linux";
					modules = [
						({ pkgs, ...}: {
							networking.hostName = "kp2pml30-personal-pc";
							networking.hostId = "e31a5cc2";

							time.timeZone = "Asia/Tokyo";
							environment.systemPackages = [
								# pkgs.claude-code
							];
						})

						./nix/hardware/mini.nix

						./nix/common.nix

						./nix/personal

						{
							kp2pml30 = {
								xserver = true;
								vscode = true;
								kitty = true;
								opera = true;
								steam = true;

								boot.efiGrub = true;

								hardware.wireless = true;
								hardware.audio = true;

								messengers.personal = true;
								messengers.work = true;
							};
						}
					];
					specialArgs = additionalArgs // { inherit system; };
				};
				personal-laptop = nixpkgs.lib.nixosSystem rec {
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

								boot.efiGrub = true;

								hardware.wireless = true;
								hardware.audio = true;

								messengers.personal = true;
							};
						}
					];
					specialArgs = additionalArgs // { inherit system; };
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
						./nix/personal
					];
					specialArgs = additionalArgs;
				};
			};
		};
}
