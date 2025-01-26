{ config
, pkgs
, lib
, ...
}@args:
let
	cfg = config.kp2pml30.server;
	src = builtins.fetchGit {
		url = "https://github.com/kp2pml30/kp2pml30.github.io.git";
		rev = "0a887a1cd439c93efbe7d46c158102387b6fc470";
	};
	pack = (import "${src}/release.nix" args);
in lib.mkIf cfg.nginx {
	environment.systemPackages = [ pack ];
	kp2pml30.server.sitePath = pack.outPath;
}
