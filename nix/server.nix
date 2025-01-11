{ config, pkgs, ... }:
let
	mhostname = "example.org" ;
in
{
	services.openssh = {
		enable = true;
		ports = [ 22 ];
		openFirewall = true;
		settings = {
			PasswordAuthentication = false;
			KbdInteractiveAuthentication = false;
			AllowUsers = [ "kp2pml30-serv" ];
		};
	};

	users.users.kp2pml30-serv = import ./user.nix;
	users.users.nginx.extraGroups = [ "acme" ];

	security.acme = {
		acceptTerms = true;
		defaults.email = "kp2pml30@gmail.com";
		certs."${mhostname}" = {
			serverAliases = [ "*.${mhostname}" ];
			webroot = "/var/lib/acme/.challenges";
			group = "nginx";
			#extraDomainNames = [ "mail.example.org" ];
		};
	};
	services.nginx = {
		virtualHosts."${mhostname}" = {
			enableACME = true;
			listen = [
				{ port = 80; }
			];
			locations."/.well-known/acme-challenge/" = {
				root = "/var/lib/acme/.challenges";
			};
			locations."/" = {
				return = 404;
			};
		};
		streamConfig = (builtins.readFile ./stream.nginx);
	};
}
