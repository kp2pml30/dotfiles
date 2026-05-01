{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
		nixos-wsl = {
			url = "github:nix-community/NixOS-WSL/main";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		home-manager = {
			url = "github:nix-community/home-manager/release-25.11";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		nixos-generators = {
			url = "github:nix-community/nixos-generators";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		kp2pml30-moe = {
			url = "github:kp2pml30/kp2pml30.github.io";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		code-flake = {
			url = "github:kp2pml30/code-flake";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		claude-code = {
			url = "github:sadjow/claude-code-nix";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs@{ self, nixpkgs, nixos-wsl, home-manager, nixos-generators, kp2pml30-moe, code-flake, claude-code, ... }:
		let
			rootPath = self;
			user-groups-ids = import ./nix/user-groups-ids.nix;
			additionalArgs = { inherit inputs rootPath user-groups-ids; };
			lib = nixpkgs.lib;
		in
		{
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

					specialArgs = { inherit kp2pml30-moe user-groups-ids; system = "x86_64-linux"; };
				};

				personal-pc = nixpkgs.lib.nixosSystem rec {
					system = "x86_64-linux";
					modules = [
						({ pkgs, ...}: {
							networking.hostName = "kp2pml30-personal-pc";
							networking.hostId = "e31a5cc2";

							time.timeZone = "Asia/Tokyo";

							nixpkgs.overlays = [ claude-code.overlays.default code-flake.overlays.default ];
						})

						./nix/hardware/mini.nix

						./nix/common.nix

						./nix/personal

						./nix/qemu.nix

						./nix/xray.nix

						{
							kp2pml30 = {
								xserver = true;
								vscode = true;
								kitty = true;
								opera = true;
								steam = true;
								claude = true;

								qemu = true;

								xray-client = true;
								xray-client-id = "mini";

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

							nixpkgs.overlays = [ code-flake.overlays.default ];
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

				claude-vm = nixpkgs.lib.nixosSystem {
					system = "x86_64-linux";
					modules = [
						{ networking.hostId = "c1a0de00"; }
						./nix/common.nix
						./nix/claude-vm
						./nix/personal
						./nix/hardware/claude-vm.nix
					];
					specialArgs = additionalArgs;
				};

				claude-vm-installer = nixpkgs.lib.nixosSystem {
					system = "x86_64-linux";
					modules = [
						./nix/claude-vm/installer.nix
					];
					specialArgs = additionalArgs;
				};
			};
		};
}
