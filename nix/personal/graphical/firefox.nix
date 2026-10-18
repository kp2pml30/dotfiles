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

      # RFP spoofs the timezone as UTC, the locale as en-US and the screen size;
      # letterboxing pads the viewport to a coarse grid so window size stops being an id
      "privacy.resistFingerprinting" = true;
      "privacy.resistFingerprinting.letterboxing" = true;

      "browser.contentblocking.category" = "strict";
      "privacy.trackingprotection.enabled" = true;
      "privacy.trackingprotection.socialtracking.enabled" = true;
      "privacy.trackingprotection.cryptomining.enabled" = true;
      "privacy.trackingprotection.fingerprinting.enabled" = true;

      # 5 = dFPI: third parties keep state, partitioned per top-level site
      "network.cookie.cookieBehavior" = 5;
      "privacy.partition.network_state" = true;
      "privacy.query_stripping.enabled" = true;
      "privacy.query_stripping.enabled.pbmode" = true;
      "privacy.globalprivacycontrol.enabled" = true;

      # 2 = send a referer only same-origin, and trim it to the origin cross-origin
      "network.http.referer.XOriginPolicy" = 2;
      "network.http.referer.XOriginTrimmingPolicy" = 2;
      "beacon.enabled" = false;

      # webrtc negotiates its own sockets and would bypass the proxy outright
      "media.peerconnection.ice.proxy_only" = true;

      # speculative connections resolve and dial hosts the user never visits
      "network.prefetch-next" = false;
      "network.dns.disablePrefetch" = true;
      "network.predictor.enabled" = false;

      "datareporting.healthreport.uploadEnabled" = false;
      "datareporting.policy.dataSubmissionEnabled" = false;
      "toolkit.telemetry.enabled" = false;
      "toolkit.telemetry.unified" = false;
      "toolkit.telemetry.archive.enabled" = false;
      "app.shield.optoutstudies.enabled" = false;
      "browser.discovery.enabled" = false;
      "browser.newtabpage.activity-stream.feeds.telemetry" = false;
    };
  };
}
