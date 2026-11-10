{
  config,
  lib,
  pkgs,
  data,
  ...
}:
let
  ports = config.kp2pml30.server.ports;
  tun = data.network.tunnel;
  common = import ./common.nix data;
  inherit (data.mail)
    domain
    accounts
    reserved
    dkim
    ;

  address = local: "${local}@${domain}";
  secrets = "/run/secrets/mail";
  keys = "/run/mail-keys";

  localParts =
    lib.attrNames accounts ++ lib.concatMap (a: a.aliases) (lib.attrValues accounts) ++ reserved.names;
in
{
  assertions = [
    {
      assertion = config.kp2pml30.server.tunnel == "host";
      message = "mail host receives and sends through the tunnel";
    }
    {
      assertion = accounts ? ${reserved.owner};
      message = "mail: reserved owner ${reserved.owner} is not an account";
    }
    {
      assertion = lib.length (lib.unique localParts) == lib.length localParts;
      message = "mail: local parts must be unique across accounts, aliases and reserved";
    }
  ];

  mailserver = {
    enable = true;
    stateVersion = 5;
    inherit (common) fqdn;
    # vdsina's PTR, shared with everything else it hosts
    sendingFqdn = domain;
    domains = [ domain ];
    openFirewall = false;

    accounts = lib.mapAttrs' (
      name: acc:
      lib.nameValuePair (address name) {
        hashedPasswordFile = "${secrets}/${name}.hash";
        aliases = map address (acc.aliases ++ lib.optionals (name == reserved.owner) reserved.names);
      }
    ) accounts;

    x509.useACMEHost = common.fqdn;

    # Implicit TLS only; clients reach these over the tailnet (trusted interface)
    enableImap = false;
    enableImapSsl = true;
    enablePop3 = false;
    enablePop3Ssl = false;
    enableSubmission = false;
    enableSubmissionSsl = true;
    enableManageSieve = true;

    dkim.domains.${domain}.selectors.${dkim.selector}.keyFile = "${keys}/dkim-mail.key";

    storage = {
      uid = data.uids.virtualMail;
      gid = data.gids.virtualMail;
    };
  };

  services.postfix.settings.main = {
    # Port 25 is public; logins belong on submissions, which re-enables this
    smtpd_sasl_auth_enable = lib.mkForce false;
    smtp_bind_address = tun.nanopi-m5.ipv4;
    smtp_bind_address6 = tun.nanopi-m5.ipv6;
    # Receivers are strictest about IPv6 senders (PTR, reputation)
    smtp_address_preference = "ipv4";
    # Behind vdsina's DNAT: an MX pointing there is this host
    proxy_interfaces = "${data.network.machines.vdsina.ipv4}, [${data.network.machines.vdsina.ipv6}]";
  };

  # Spamhaus & co refuse queries arriving through public resolvers
  services.rspamd.locals."options.inc".text = ''
    dns {
      nameserver = ["127.0.0.1:53"];
    }
  '';

  users.users.redis-rspamd.uid = data.uids.redis-rspamd;
  users.groups.redis-rspamd.gid = data.gids.redis-rspamd;
  users.users.knot-resolver.uid = data.uids.knot-resolver;
  users.groups.knot-resolver.gid = data.gids.knot-resolver;
  users.users.postfix-tlspol.uid = data.uids.postfix-tlspol;
  users.groups.postfix-tlspol.gid = data.gids.postfix-tlspol;
  users.users.acme.uid = data.uids.acme;
  users.groups.acme.gid = data.gids.acme;

  security.acme = {
    acceptTerms = true;
    defaults.email = "kp2pml30@gmail.com";
    certs.${common.fqdn}.listenHTTP = ":${toString ports.mail-acme}";
  };

  networking.firewall.interfaces.${tun.interface}.allowedTCPPorts = common.publicPorts ++ [
    ports.mail-acme
  ];

  # /run/secrets is root-only; hand rspamd its own copy
  systemd.services.mail-keys = {
    description = "Install mail secrets for their consumers";
    wantedBy = [ "multi-user.target" ];
    requires = [ "decrypt-secrets.service" ];
    after = [ "decrypt-secrets.service" ];
    before = [ "rspamd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0711 ${keys}
      install -m 0400 -o rspamd -g rspamd ${secrets}/dkim-mail.key ${keys}/dkim-mail.key
    '';
  };
  systemd.services.rspamd = {
    requires = [ "mail-keys.service" ];
    after = [ "mail-keys.service" ];
  };
  systemd.services.dovecot = {
    requires = [ "decrypt-secrets.service" ];
    after = [ "decrypt-secrets.service" ];
  };
  # The HTTP-01 challenge arrives over the tunnel
  systemd.services."acme-order-renew-${common.fqdn}" = {
    wants = [ "tunnel-keys.service" ];
    after = [ "tunnel-keys.service" ];
  };
}
