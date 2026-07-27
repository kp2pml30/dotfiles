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
