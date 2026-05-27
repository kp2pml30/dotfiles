{ config, ... }:
let
	cfg = config.kp2pml30.server;
	ports = config.kp2pml30.server.ports;
	dnsPort = 53;
	httpPort = 80;
	httpsPort = 443;
	dnsOverTlsPort = 853;
in {
	networking.firewall = {
		allowedTCPPorts = [ dnsPort httpPort httpsPort dnsOverTlsPort ];
		allowedUDPPorts = [ dnsPort ]
			++ (if cfg.headscale then [ ports.headscale-stun ] else []);
	};
}
