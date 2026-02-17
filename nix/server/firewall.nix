{ ... }:
let
	dnsPort = 53;
	httpPort = 80;
	httpsPort = 443;
	dnsOverTlsPort = 853;
in {
	networking.firewall = {
		allowedTCPPorts = [ dnsPort httpPort httpsPort dnsOverTlsPort ];
		allowedUDPPorts = [ dnsPort ];
	};
}
