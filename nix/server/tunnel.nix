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
  tun = data.network.tunnel;
  iface = tun.interface;
  keys = "/run/tunnel-keys";
  # Routes everything sourced from the tunnel addresses out via vdsina
  routeTable = 2525;
  # nanopi-m5's uplink path MTU is 1454 (double NAT); wireguard's 1420 default blackholes
  mtu = 1280;
in
lib.mkMerge [
  (lib.mkIf (cfg.tunnel == "relay") {
    networking.wireguard.interfaces.${iface} = {
      ips = [
        "${tun.vdsina.ipv4}/24"
        "${tun.vdsina.ipv6}/64"
      ];
      listenPort = ports.tunnel-wg;
      inherit mtu;
      privateKeyFile = "/run/secrets/tunnel/wg-vdsina";
      peers = [
        {
          publicKey = tun.nanopi-m5.wg-pub;
          allowedIPs = [
            "${tun.nanopi-m5.ipv4}/32"
            "${tun.nanopi-m5.ipv6}/128"
          ];
        }
      ];
    };
    systemd.services."wireguard-${iface}" = {
      after = [ "decrypt-secrets.service" ];
      requires = [ "decrypt-secrets.service" ];
    };

    networking.firewall.allowedUDPPorts = [ ports.tunnel-wg ];
  })

  (lib.mkIf (cfg.tunnel == "host") {
    systemd.network.netdevs."50-${iface}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = iface;
      };
      wireguardConfig = {
        # Absent until tunnel-keys installs it; networkd skips the netdev till then
        PrivateKeyFile = "${keys}/wg";
        RouteTable = routeTable;
      };
      wireguardPeers = [
        {
          PublicKey = tun.vdsina.wg-pub;
          Endpoint = "${data.network.machines.vdsina.ipv4}:${toString ports.tunnel-wg}";
          AllowedIPs = [
            "0.0.0.0/0"
            "::/0"
          ];
          PersistentKeepalive = 25;
        }
      ];
    };
    systemd.network.networks."50-${iface}" = {
      matchConfig.Name = iface;
      address = [
        "${tun.nanopi-m5.ipv4}/24"
        "${tun.nanopi-m5.ipv6}/64"
      ];
      routingPolicyRules = [
        {
          From = tun.nanopi-m5.ipv4;
          Table = routeTable;
          Priority = 1000;
        }
        {
          From = tun.nanopi-m5.ipv6;
          Table = routeTable;
          Priority = 1000;
        }
      ];
      linkConfig = {
        RequiredForOnline = "no";
        MTUBytes = toString mtu;
      };
    };

    # The peer accepts any source: vdsina may only reach the tunnel address, and
    # never be routed onward (mangle runs before Docker's filter chains)
    networking.firewall.extraCommands = ''
      iptables -t raw -I PREROUTING -i ${iface} ! -d ${tun.nanopi-m5.ipv4} -j DROP
      ip6tables -t raw -I PREROUTING -i ${iface} ! -d ${tun.nanopi-m5.ipv6} -j DROP
      ip46tables -t mangle -I FORWARD -i ${iface} -j DROP
    '';
    networking.firewall.extraStopCommands = ''
      iptables -t raw -D PREROUTING -i ${iface} ! -d ${tun.nanopi-m5.ipv4} -j DROP 2>/dev/null || true
      ip6tables -t raw -D PREROUTING -i ${iface} ! -d ${tun.nanopi-m5.ipv6} -j DROP 2>/dev/null || true
      ip46tables -t mangle -D FORWARD -i ${iface} -j DROP 2>/dev/null || true
    '';

    # /run/secrets is root-only; networkd needs its own copy
    systemd.services.tunnel-keys = {
      description = "Install the tunnel WireGuard key for networkd";
      wantedBy = [ "multi-user.target" ];
      requires = [ "decrypt-secrets.service" ];
      after = [
        "decrypt-secrets.service"
        "systemd-networkd.service"
      ];
      path = [ pkgs.diffutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -m 0711 ${keys}
        # reload only creates missing netdevs; a rotated key needs the link recreated
        if ! cmp -s /run/secrets/tunnel/wg-nanopi-m5 ${keys}/wg; then
          install -m 0640 -o root -g systemd-network /run/secrets/tunnel/wg-nanopi-m5 ${keys}/wg
          networkctl delete ${iface} 2>/dev/null || true
        fi
        networkctl reload
      '';
    };
  })
]
