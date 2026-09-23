{
  lib,
  data,
  ...
}:
{
  # ./personal owns the user; here it is `agent`, so the agent tooling and
  # home-manager files land in the user whose home is the persistent share.
  users.users.agent = {
    uid = lib.mkForce data.uids.agent;
    hashedPassword = lib.mkForce "";
  };

  users.users.root.hashedPassword = "";

  security.sudo.wheelNeedsPassword = false;

  # Only reachable over vsock from the host; slirp gives no inbound path.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkForce true;
      PermitRootLogin = lib.mkForce "yes";
      PermitEmptyPasswords = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
