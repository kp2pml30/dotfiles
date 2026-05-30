{ pkgs
, config
, lib
, rootPath
, ...
}:
let
	cfg = config.kp2pml30;
	luaStr = s: "\"" + builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s + "\"";
	tuiEntries = lib.filterAttrs
		(_: e: builtins.elem "X-TUI" (e.categories or [ ]))
		config.home-manager.users.${cfg.username}.xdg.desktopEntries;
	tuiMenuLua = ''
		-- Generated from xdg.desktopEntries tagged with X-TUI
		return {
		${lib.concatStringsSep "\n" (lib.mapAttrsToList
			(_: e: "\t{ ${luaStr e.name}, ${luaStr e.exec} },")
			tuiEntries)}
		}
	'';
in lib.mkIf cfg.xserver {
	# Workaround for https://github.com/NixOS/nixpkgs/issues/523345
	# (lgi's ffi.load_enum breaks on GLib >= 2.87). Nixpkgs already applies
	# a partial fix; this adds the missing n_values / ipairs hunk.
	nixpkgs.overlays = [ (final: prev: {
		awesome = prev.awesome.override {
			lua = prev.lua.override {
				packageOverrides = lfinal: lprev: {
					lgi = lprev.lgi.overrideAttrs (old: {
						patches = (old.patches or [ ]) ++ [
							(rootPath + "/nix/patches/lgi-glib-2.87.patch")
						];
					});
				};
			};
		};
	}) ];

	services.displayManager.ly.enable = true;
	services.libinput.enable = true;
	services.xserver = {
		enable = true;
		displayManager.startx.enable = true;
		xkb = {
			layout = "us,ru";
			variant = ",";
			options = "grp:win_space_toggle";
		};
		windowManager.awesome = {
			enable = true;
			luaModules = with pkgs.luaPackages; [
				luarocks
				luadbi-mysql
			];
		};
		excludePackages = lib.optionals (!cfg.kitty) [
			pkgs.xterm
		];
	};

	environment.systemPackages = with pkgs; [
		xclip
		brightnessctl
		arandr
		libnotify
		xfce4-screenshooter
	];

	services.picom = {
		enable = true;
		vSync = true;
		backend = "glx";
	};

	programs.dconf.enable = true;

	users.users.${cfg.username} = {
		packages = with pkgs; [
			rofimoji
		];
	};

	home-manager.users.${cfg.username} = {
		programs.rofi = {
			enable = true;
			theme = "simple-tokyonight";
			location = "center";
		};
		home.file.".config/rofi/simple-tokyonight.rasi" = { source = rootPath + "/home/.config/rofi/simple-tokyonight.rasi"; };

		home.file.".config/awesome/rc.lua" = { source = rootPath + "/home/.config/awesome/rc.lua"; };
		home.file.".config/awesome/theme.lua" = { source = rootPath + "/home/.config/awesome/theme.lua"; };
		home.file.".config/awesome/tui-menu.lua".text = tuiMenuLua;
		home.file.".config/awesome/deficient" = {
			source = builtins.fetchGit {
				url = "https://github.com/deficient/deficient.git";
				rev = "22ad2bea198f0c231afac0b7197d9b4eb6d80da3";
			};
			recursive = true;
		};
	};
}
