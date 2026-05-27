# Single source of truth for user IDs across hosts.
# Values match current state on the live machines so existing on-disk
# ownership stays valid.
{
	# personal
	kp2pml30             = 1000;

	# server
	kp2pml30-moe-backend = 1001;
	xray                 = 993;
	coredns              = 992;
	forgejo              = 994;
	acme                 = 995;

	# claude-vm
	claude               = 1200;

	# Pinned upstream by nixpkgs (nixos/modules/misc/ids.nix);
	# recorded here for visibility / collision avoidance only:
	#   root=0, messagebus=4, nginx=60, postgres=71,
	#   systemd-coredump=151, systemd-network=152,
	#   systemd-resolve=153, systemd-timesync=154,
	#   systemd-oom=996, sshd=997, nscd=998, dhcpcd=999.
}
