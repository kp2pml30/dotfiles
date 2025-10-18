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
  };
}