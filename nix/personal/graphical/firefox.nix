{
  lib,
  config,
  ...
}:
let
  cfg = config.kp2pml30;

  inbounds = (builtins.fromJSON (builtins.readFile ../../server/xray-client.json)).inbounds;
  inbound =
    protocol:
    lib.findFirst (
      i: i.protocol == protocol
    ) (throw "no ${protocol} inbound in xray-client.json") inbounds;
  proxyAddr =
    protocol:
    let
      i = inbound protocol;
    in
    "${i.listen}:${toString i.port}";
in
lib.mkIf cfg.xserver {
  programs.firefox = {
    enable = true;

    # not locked, so the proxy stays togglable from the UI
    policies = lib.mkIf cfg.xray-client {
      Proxy = {
        Mode = "manual";
        HTTPProxy = proxyAddr "http";
        SSLProxy = proxyAddr "http";
        SOCKSProxy = proxyAddr "socks";
        SOCKSVersion = 5;
        UseHTTPProxyForAllProtocols = true;
        Locked = false;
      };
    };

    preferences = {
      "browser.shell.checkDefaultBrowser" = false;
      "browser.search.serpEventTelemetryCategorization.regionEnabled" = false;
      "media.eme.enabled" = true;

      "dom.security.https_only_mode" = true;
      "dom.security.https_only_mode_ever_enabled" = true;

      # trr mode 3 = DoH only, no system-resolver fallback
      "network.trr.mode" = 3;
      "network.trr.uri" = "https://dns.kp2pml30.moe/dns-query";
      "network.trr.custom_uri" = "https://dns.kp2pml30.moe/dns-query";

      # 3 = new tab; restriction 0 makes it apply even to window.open with features
      "browser.link.open_newwindow" = 3;
      "browser.link.open_newwindow.restriction" = 0;

      # only a deliberate click may raise a popup
      "dom.popup_allowed_events" = "click dblclick auxclick";
    };
  };
}
