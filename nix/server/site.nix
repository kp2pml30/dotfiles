{ config
, pkgs
, lib
, ...
}@args:
let
	cfg = config.kp2pml30.server;
	src = builtins.fetchGit {
		url = "https://github.com/kp2pml30/kp2pml30.github.io.git";
		rev = "98e76b9ca1c9bcf619b2dae28601dc3c926dfa01";
	};
	pack = (import "${src}/release.nix" args);
in lib.mkIf cfg.nginx {
	environment.systemPackages = [ pack ];
	kp2pml30.server.sitePath = pack.outPath;
}
