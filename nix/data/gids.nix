# Single source of truth for group IDs across hosts.
{
	users       = 100;
	steam-input = 988;
	certreaders = 990;
	coredns     = 989;
	xray        = 991;
	forgejo     = 992;
	acme        = 993;

	# Pinned upstream (see uids.nix for the equivalent note):
	#   root=0, messagebus=4, nginx=60, postgres=71,
	#   systemd-network=152, systemd-resolve=153, systemd-timesync=154,
	#   systemd-oom=994, systemd-coredump=995,
	#   sshd=996, nscd=998, dhcpcd=999.
}
