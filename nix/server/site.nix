{ config
, pkgs
, lib
, ...
}@args:
let
	cfg = config.kp2pml30.server;
	src = builtins.fetchGit {
		url = "https://github.com/kp2pml30/kp2pml30.github.io.git";
		rev = "855fb5c51c439179aeedf83e1b0ecdb0d4385023";
	};
	pack = (import "${src}/release.nix" args);
in lib.mkIf cfg.nginx {
	environment.systemPackages = [ pack ];
	kp2pml30.server.sitePath = pack.outPath;
}
