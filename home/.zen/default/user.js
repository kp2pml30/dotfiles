user_pref("zen.view.experimental-no-window-controls", true);

// no built-in password manager
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
user_pref("signon.generation.enabled", false);
user_pref("signon.management.page.breach-alerts.enabled", false);

user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// trr mode 3 = DoH only, no system-resolver fallback
user_pref("network.trr.mode", 3);
user_pref("network.trr.uri", "https://dns.kp2pml30.moe/dns-query");
user_pref("network.trr.custom_uri", "https://dns.kp2pml30.moe/dns-query");

user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.search.serpEventTelemetryCategorization.regionEnabled", false);
user_pref("media.eme.enabled", true);

// 3 = new tab; restriction 0 makes it apply even to window.open with features
user_pref("browser.link.open_newwindow", 3);
user_pref("browser.link.open_newwindow.restriction", 0);

// only a deliberate click may raise a popup
user_pref("dom.popup_allowed_events", "click dblclick auxclick");
