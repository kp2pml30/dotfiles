data: {
  fqdn = "mail.${data.mail.domain}";
  # Forwarded vdsina -> nanopi-m5; clients log in over the tailnet instead
  publicPorts = [ 25 ];
}
