{ lib, ... }:
{
  # Server Port Usage Configuration
  # This file documents and centralizes all port assignments

  options.kp2pml30.server.ports = {
    # Application Services
    backend = lib.mkOption {
      type = lib.types.int;
      default = 8001;
      description = "Backend service port (kp2pml30-moe-backend)";
    };

    forgejo = lib.mkOption {
      type = lib.types.int;
      default = 8002;
      description = "Forgejo Git service port";
    };

    coredns-https = lib.mkOption {
      type = lib.types.int;
      default = 8003;
      description = "CoreDNS HTTPS interface port";
    };

    # Available ports for new services
    xray-main = lib.mkOption {
      type = lib.types.int;
      default = 8010;
      description = "Xray VLESS inbound port";
    };

    xray-fallback = lib.mkOption {
      type = lib.types.int;
      default = 8011;
      description = "Xray fallback proxy port";
    };

    xray-websocket = lib.mkOption {
      type = lib.types.int;
      default = 8012;
      description = "Xray websocket fallback port";
    };

    signal-proxy-port = lib.mkOption {
      type = lib.types.int;
      default = 8444;
      description = "Signal proxy TLS termination port";
    };

    headscale = lib.mkOption {
      type = lib.types.int;
      default = 8020;
      description = "Headscale HTTP control plane (behind nginx)";
    };

    headscale-grpc = lib.mkOption {
      type = lib.types.int;
      default = 8021;
      description = "Headscale gRPC (localhost admin CLI)";
    };

    headscale-metrics = lib.mkOption {
      type = lib.types.int;
      default = 8022;
      description = "Headscale Prometheus metrics";
    };

    headscale-stun = lib.mkOption {
      type = lib.types.int;
      default = 3478;
      description = "Embedded DERP STUN (UDP, public)";
    };
  };
}