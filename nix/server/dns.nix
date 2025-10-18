
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
	ports = config.kp2pml30.server.ports;
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

		https://.:${toString ports.coredns-https} {
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
