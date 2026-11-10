{
  config,
  lib,
  pkgs,
  data,
  ...
}:
let
  cfg = config.kp2pml30.server;
  ports = cfg.ports;
  vdsina = data.network.machines.vdsina;
  tun = data.network.tunnel;
  common = import ./common.nix data;
  inherit (data.mail) domain dkim;
  acmeRoot = "/var/lib/acme/acme-challenge";

  listen80 = [
    {
      addr = "0.0.0.0";
      port = 80;
    }
    {
      addr = "[::]";
      port = 80;
    }
  ];

  # Starts in testing: senders report, but still deliver on TLS failures
  mtaSts = ''
    version: STSv1
    mode: testing
    mx: ${common.fqdn}
    max_age: 604800
  '';
  mtaStsId = builtins.substring 0 20 (builtins.hashString "sha256" mtaSts);

  autoconfig = pkgs.writeText "config-v1.1.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <clientConfig version="1.1">
      <emailProvider id="${domain}">
        <domain>${domain}</domain>
        <displayName>${domain}</displayName>
        <displayShortName>${domain}</displayShortName>
        <incomingServer type="imap">
          <hostname>${common.fqdn}</hostname>
          <port>993</port>
          <socketType>SSL</socketType>
          <authentication>password-cleartext</authentication>
          <username>%EMAILADDRESS%</username>
        </incomingServer>
        <outgoingServer type="smtp">
          <hostname>${common.fqdn}</hostname>
          <port>465</port>
          <socketType>SSL</socketType>
          <authentication>password-cleartext</authentication>
          <username>%EMAILADDRESS%</username>
        </outgoingServer>
      </emailProvider>
    </clientConfig>
  '';
  autoconfigLocation = {
    alias = autoconfig;
    extraConfig = "default_type application/xml;";
  };

  # TXT strings are capped at 255 bytes
  txtChunks =
    s:
    if builtins.stringLength s <= 250 then
      [ s ]
    else
      [ (builtins.substring 0 250 s) ] ++ txtChunks (builtins.substring 250 (-1) s);
  dkimTxt = lib.concatMapStringsSep " " (c: ''"${c}"'') (txtChunks "v=DKIM1; k=rsa; p=${dkim.pub}");

  srv = service: port: "_${service}._tcp IN SRV 0 1 ${toString port} ${common.fqdn}.";
  # RFC 6186: target "." means the service is deliberately not offered
  noSrv = service: "_${service}._tcp IN SRV 0 0 0 .";
in
lib.mkIf cfg.mail-relay {
  assertions = [
    {
      assertion = cfg.nginx && cfg.hostname == domain;
      message = "mail-relay serves ${domain} through this host's nginx and zone";
    }
    {
      assertion = cfg.tunnel == "relay";
      message = "mail-relay forwards to nanopi-m5 through the tunnel";
    }
  ];

  # Mail only passes through the kernel here; nothing readable touches disk
  networking.nat = {
    enable = true;
    enableIPv6 = true;
    internalIPs = [ "${tun.nanopi-m5.ipv4}/32" ];
    internalIPv6s = [ "${tun.nanopi-m5.ipv6}/128" ];
    forwardPorts = lib.concatMap (port: [
      {
        sourcePort = port;
        proto = "tcp";
        destination = "${tun.nanopi-m5.ipv4}:${toString port}";
      }
      {
        sourcePort = port;
        proto = "tcp";
        destination = "[${tun.nanopi-m5.ipv6}]:${toString port}";
      }
    ]) common.publicPorts;
  };

  # NAT turns forwarding on for every interface; forward only the tunnel:
  # in, only the DNAT'd ports; out, only SMTP, so nanopi can't spend this IP's reputation
  networking.firewall.extraCommands = ''
    ip46tables -I FORWARD ! -i ${tun.interface} ! -o ${tun.interface} -j DROP
    ip46tables -I FORWARD -o ${tun.interface} -m conntrack ! --ctstate DNAT,RELATED,ESTABLISHED -j DROP
    ip46tables -I FORWARD -i ${tun.interface} -m conntrack --ctstate NEW ! -p tcp -j DROP
    ip46tables -I FORWARD -i ${tun.interface} -m conntrack --ctstate NEW -p tcp ! --dport 25 -j DROP
  '';
  networking.firewall.extraStopCommands = ''
    ip46tables -D FORWARD ! -i ${tun.interface} ! -o ${tun.interface} -j DROP 2>/dev/null || true
    ip46tables -D FORWARD -o ${tun.interface} -m conntrack ! --ctstate DNAT,RELATED,ESTABLISHED -j DROP 2>/dev/null || true
    ip46tables -D FORWARD -i ${tun.interface} -m conntrack --ctstate NEW ! -p tcp -j DROP 2>/dev/null || true
    ip46tables -D FORWARD -i ${tun.interface} -m conntrack --ctstate NEW -p tcp ! --dport 25 -j DROP 2>/dev/null || true
  '';

  services.nginx.virtualHosts = {
    # nanopi-m5 holds its own certificate; only the HTTP-01 challenge passes here
    ${common.fqdn} = {
      listen = listen80;
      locations."/.well-known/acme-challenge/".proxyPass =
        "http://${tun.nanopi-m5.ipv4}:${toString ports.mail-acme}";
      locations."/".return = "404";
    };

    "mta-sts.${domain}" = {
      enableACME = true;
      inherit acmeRoot;
      listen = listen80;
      locations."= /.well-known/mta-sts.txt" = {
        alias = pkgs.writeText "mta-sts.txt" mtaSts;
        extraConfig = "default_type text/plain;";
      };
    };

    "autoconfig.${domain}" = {
      enableACME = true;
      inherit acmeRoot;
      listen = listen80;
      locations."= /mail/config-v1.1.xml" = autoconfigLocation;
    };

    ${domain}.locations."= /.well-known/autoconfig/mail/config-v1.1.xml" = autoconfigLocation;
  };

  kp2pml30.server.zoneExtraRecords = ''
    mail IN A ${vdsina.ipv4}
    mail IN AAAA ${vdsina.ipv6}
    @ IN MX 10 ${common.fqdn}.
    @ IN TXT "v=spf1 ip4:${vdsina.ipv4} ip6:${vdsina.ipv6} -all"
    _dmarc IN TXT "v=DMARC1; p=quarantine; rua=mailto:postmaster@${domain}"
    ${dkim.selector}._domainkey IN TXT ${dkimTxt}
    _mta-sts IN TXT "v=STSv1; id=${mtaStsId}"
    _smtp._tls IN TXT "v=TLSRPTv1; rua=mailto:postmaster@${domain}"
    ${srv "submissions" 465}
    ${srv "imaps" 993}
    ${srv "sieve" 4190}
    ${noSrv "submission"}
    ${noSrv "imap"}
    ${noSrv "pop3s"}
    ${noSrv "pop3"}
  '';
}
