
{ config
, pkgs
, lib
, self
, nixpkgs
, kp2pml30-moe
, system
, user-groups-ids
, ...
}@args:
let
	cfg = config.kp2pml30.server;
	ports = config.kp2pml30.server.ports;
	ips = import ./ips.nix;

	hostname = cfg.hostname;

	relName = fullAddr:
		let stripped = lib.removeSuffix ".${hostname}" fullAddr;
		in if stripped == fullAddr then "@" else stripped;

	domainEntries = lib.mapAttrsToList (_: v: {
		name = relName v.full-address;
		ip = v.ip;
		ipv6 = v.ipv6;
	}) ips.addresses;

	zoneRecords = lib.concatMapStringsSep "\n" (e:
		"${e.name} IN A ${e.ip}\n"
		+ "${e.name} IN AAAA ${e.ipv6}\n"
		+ "${e.name} IN HTTPS 1 . alpn=h2,http/1.1 ipv4hint=${e.ip} ipv6hint=${e.ipv6}"
	) domainEntries;

	zoneFile = pkgs.writeText "${hostname}.zone" ''
$ORIGIN ${hostname}.
$TTL 300
@ IN SOA dns.${hostname}. admin.${hostname}. ( 1 3600 600 604800 300 )
@ IN NS dns.${hostname}.
@ IN NS dns2.${hostname}.
www IN CNAME ${hostname}.
${zoneRecords}
'';
in lib.mkIf cfg.nginx {
	users.users.coredns = {
		isSystemUser = true;
		uid = user-groups-ids.uids.coredns;
		group = "coredns";
		extraGroups = [ "certreaders" ];
	};
	users.groups.coredns = { gid = user-groups-ids.gids.coredns; };

	services.coredns.enable = true;
	services.coredns.config = ''
		${hostname} {
			file ${zoneFile}
		}

		dns://.:53 {
			forward . tls://1.1.1.1 tls://1.0.0.1 {
				tls_servername cloudflare-dns.com
				policy random
			}
			cache
		}

		tls://.:853 {
			tls /var/lib/acme/${hostname}/fullchain.pem /var/lib/acme/${hostname}/key.pem
			forward . dns://127.0.0.1:53
		}

		https://.:${toString ports.coredns-https} {
			forward . dns://127.0.0.1:53
		}
	'';
	# networking.networkmanager.insertNameservers = [ "127.0.0.1" ];
}
