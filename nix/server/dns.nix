
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
in lib.mkIf cfg.nginx {
	services.coredns.enable = true;
	services.coredns.config = ''
		dns://.:53 {
			forward . tls://1.1.1.1 {
				tls
				tls_servername cloudflare-dns.com
			}
			cache
		}

		https://.:8003 {
			forward . dns://127.0.0.1:53 {
				tls
				tls_servername cloudflare-dns.com
				policy random
			}
			cache
		}
	'';
	# networking.networkmanager.insertNameservers = [ "127.0.0.1" ];
}
