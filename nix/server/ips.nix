rec {
	machines = {
		vdsina = "146.103.126.11";
		vdsina-v6 = "2a14:1e00:3:44d::1";
	};
	addresses = {
		forgejo    = { ip = machines.vdsina; ipv6 = machines.vdsina-v6; full-address = "git.kp2pml30.moe"; };
		www        = { ip = machines.vdsina; ipv6 = machines.vdsina-v6; full-address = "kp2pml30.moe"; };
		xray         = { ip = machines.vdsina; ipv6 = machines.vdsina-v6; full-address = "x.kp2pml30.moe"; };
		dns        = { ip = machines.vdsina; ipv6 = machines.vdsina-v6; full-address = "dns.kp2pml30.moe"; };
		dns2       = { ip = machines.vdsina; ipv6 = machines.vdsina-v6; full-address = "dns2.kp2pml30.moe"; };
		signal-proxy = { ip = machines.vdsina; ipv6 = machines.vdsina-v6; full-address = "pr.kp2pml30.moe"; };
		nix-cache  = { ip = machines.vdsina; ipv6 = machines.vdsina-v6; full-address = "cache.nix.kp2pml30.moe"; };
		backend    = { ip = machines.vdsina; ipv6 = machines.vdsina-v6; full-address = "backend.kp2pml30.moe"; };
	};
}
