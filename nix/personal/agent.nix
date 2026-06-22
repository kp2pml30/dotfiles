{ config
, lib
, rootPath
, ...
}:
let
	cfg = config.kp2pml30;
in {
	config = lib.mkIf cfg.agent {
		home-manager.users.${cfg.username}.home.file = {
			".claude/skills".source = rootPath + "/agents/skills";

			".pi/agent/skills".source = rootPath + "/agents/skills";
			".pi/agent/settings.json".source = rootPath + "/agents/pi/settings.json";
			# auto-discovered from ~/.pi/agent/extensions/*/index.ts
			".pi/agent/extensions/deepinfra".source = rootPath + "/agents/pi/ext/deepinfra";
		};
	};
}
