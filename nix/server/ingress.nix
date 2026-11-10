{
  config,
  lib,
  data,
  ...
}:
let
  cfg = config.kp2pml30.server;
  ports = cfg.ports;
  tun = data.network.tunnel;
  upstream = "http://${tun.nanopi-m5.ipv4}:${toString ports.ingress-http}";
in
{
  options.kp2pml30.server.ingress.forward = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Domains whose HTTP traffic vdsina relays to nanopi-m5's nginx";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.ingress.forward != [ ]) {
      assertions = [
        {
          assertion = cfg.tunnel == "relay" && cfg.nginx;
          message = "ingress.forward needs the tunnel relay and nginx";
        }
      ];

      services.nginx.virtualHosts = lib.genAttrs cfg.ingress.forward (_: {
        enableACME = true;
        acmeRoot = "/var/lib/acme/acme-challenge";
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
          {
            addr = "[::]";
            port = 80;
          }
        ];
        locations."/" = {
          proxyPass = upstream;
          proxyWebsockets = true;
          # nanopi-m5's vhost enforces its own limit
          extraConfig = ''
            client_max_body_size 0;
            proxy_request_buffering off;
          '';
        };
      });
    })

    # Each service adds its own virtualHost, served on the tunnel address only
    (lib.mkIf (cfg.tunnel == "host") {
      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        # Bound everywhere so the tunnel may come up later; only it is let through
        defaultListen = [
          {
            addr = "0.0.0.0";
            port = ports.ingress-http;
          }
        ];
        virtualHosts."_" = {
          default = true;
          locations."/".return = "444";
        };
      };

      networking.firewall.interfaces.${tun.interface}.allowedTCPPorts = [ ports.ingress-http ];
    })
  ];
}
