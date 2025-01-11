{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		nixos-wsl = {
			url = "github:nix-community/NixOS-WSL/main";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		home-manager = {
			url = "github:nix-community/home-manager/release-24.11";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs@{ self, nixpkgs, nixos-wsl, home-manager, ... }:
		let
			rootPath = self;
			additionalArgs = { inherit inputs rootPath; };
			importArg = inputs // { pkgs = nixpkgs; lib = nixpkgs.lib; } // additionalArgs;
			hostNameMod = name: { networking.hostName = "kp2pml30-${name}"; };
			makeNamedSys = nameArg: arg: {
				"${nameArg}" =
					nixpkgs.lib.nixosSystem
					((builtins.removeAttrs arg ["modules"]) // { specialArgs = additionalArgs; modules = arg.modules ++ [(hostNameMod nameArg)]; });
			};
			makeSys = { sys }: [
				(makeNamedSys "server-${sys}" {
					system = sys;
					modules = [
						./nix/common.nix
						./nix/server.nix
					];
				})

				(makeNamedSys "personal-${sys}" {
					system = sys;
					modules = [
						./nix/common.nix
						./nix/personal.nix
					];
				})

				(makeNamedSys "personal-${sys}-wsl" {
					system = sys;
					modules = [
						./nix/wsl.nix
						./nix/common.nix
						./nix/personal.nix
					];
				})
			] ;
		in
		{
			nixosConfigurations =
				builtins.foldl'
					(x: y: x // y)
					{}
					(builtins.concatMap makeSys [ { sys = "x86_64-linux"; } ])
			;
		};
}

# example
# + nix --extra-experimental-features 'nix-command flakes' build --out-link /tmp/nixos-rebuild.ydOEVb/nixos-rebuild '.#nixosConfigurations."wsl-amd64".config.system.build.nixos-rebuild' --show-trace
# ++ readlink -e /tmp/nixos-rebuild.ydOEVb/nixos-rebuild
# + p=/nix/store/rd18dwsifrcyghim695q18nhvyfykxxg-nixos-rebuild
# exec /nix/store/rd18dwsifrcyghim695q18nhvyfykxxg-nixos-rebuild/bin/nixos-rebuild switch --flake .#wsl-amd64
