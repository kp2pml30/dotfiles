
{ config
, pkgs
, lib
, self
, nixpkgs
, kp2pml30-moe
, system
, ...
}@args:
let
	cfg = config.kp2pml30.server;
in lib.mkIf cfg.nix-cache {
	services.nix-serve = {
		enable = true;
		secretKeyFile = "/var/cache-priv-key.pem";
	};
}
