{ config
, lib
, rootPath
, pkgs
, ...
}:
let
	cfg = config.kp2pml30;

	# per-file home.file entries for every file under `src`, rooted at `dest`,
	# so the target dirs stay writable (only managed files are symlinks).
	linkTree = dest: src: lib.listToAttrs (map (f:
		lib.nameValuePair
			"${dest}/${lib.removePrefix "${toString src}/" (toString f)}"
			{ source = f; })
		(lib.filesystem.listFilesRecursive src));
in {
	config = lib.mkIf cfg.agent {
		environment.systemPackages = with pkgs; [
			claude-code
			pi-coding-agent
			rtk
		];

		home-manager.users.${cfg.username}.home.file =
			linkTree ".claude/skills" (rootPath + "/agents/skills")
			// linkTree ".pi/agent/skills" (rootPath + "/agents/skills")
			// linkTree ".pi/agent/extensions" (rootPath + "/agents/pi/ext")
			// {
				".pi/agent/settings.json".source = rootPath + "/agents/pi/settings.json";
			};
	};
}
