{ pkgs, lib, rootPath }:
let
	user = "devuser";
	uid = "1000";
	gid = "1000";

	baseVim = rootPath + "/home/.config/nvim/base.vim";

	fromGitHub = rev: repo: pkgs.vimUtils.buildVimPlugin {
		pname = "${lib.strings.sanitizeDerivationName repo}";
		version = rev;
		src = builtins.fetchGit {
			url = "https://github.com/${repo}.git";
			inherit rev;
		};
	};

	customNeovim = pkgs.neovim.override {
		configure = {
			customRC = builtins.readFile baseVim;
			packages.myPlugins = with pkgs.vimPlugins; {
				start = [
					nvim-treesitter.withAllGrammars
					nvim-autopairs
					nerdtree
					tokyonight-nvim
					barbar-nvim
					((fromGitHub "3587f57480b88e8009df7b36dc84e9c7ff8f2c49" "famiu/feline.nvim").overrideAttrs (old: {
						doCheck = false;
					}))
					(fromGitHub "d63c811337b2f75de52f16efee176695f31e7fbc" "timakro/vim-yadi")
					(fromGitHub "aafa5c187a15701a7299a392b907ec15d9a7075f" "nvim-tree/nvim-web-devicons")
				];
			};
		};
	};

	# Create passwd/group/shadow as a package
	userSetup = pkgs.runCommand "user-setup" {} ''
		mkdir -p $out/etc
		echo "root:x:0:0:root:/root:/bin/bash" > $out/etc/passwd
		echo "${user}:x:${uid}:${gid}:${user}:/home/${user}:${pkgs.bash}/bin/bash" >> $out/etc/passwd

		echo "root:x:0:" > $out/etc/group
		echo "${user}:x:${gid}:" >> $out/etc/group

		echo "root:!:1::::::" > $out/etc/shadow
		echo "${user}:!:1::::::" >> $out/etc/shadow

		mkdir -p $out/etc/nix
		cat > $out/etc/nix/nix.conf <<EOF
experimental-features = nix-command flakes
EOF

		mkdir -p $out/etc/sudoers.d
		echo "${user} ALL=(ALL) NOPASSWD: ALL" > $out/etc/sudoers.d/${user}
		chmod 440 $out/etc/sudoers.d/${user}

		mkdir -p $out/tmp
		chmod 1777 $out/tmp
	'';

	entrypoint = pkgs.writeShellScriptBin "entrypoint" ''
		if ! command -v claude &> /dev/null; then
			echo "Installing claude-code..."
			npm install -g @anthropic-ai/claude-code
		fi
		exec "$@"
	'';
in
pkgs.dockerTools.buildLayeredImage {
	name = "nix-node";
	tag = "latest";
	contents = with pkgs; [
		nix
		nodejs
		bash
		coreutils
		cacert
		git
		fish
		curl
		wget
		htop
		sudo
		customNeovim
		userSetup
		entrypoint
	];
	fakeRootCommands = ''
		mkdir -p ./home/${user}/.npm-global
		chown -R ${uid}:${gid} ./home/${user}

		mkdir -p ./usr/bin
		ln -s ${pkgs.coreutils}/bin/env ./usr/bin/env
	'';
	enableFakechroot = true;
	config = {
		Entrypoint = [ "${entrypoint}/bin/entrypoint" ];
		Cmd = [ "${pkgs.bash}/bin/bash" ];
		User = "${user}";
		WorkingDir = "/home/${user}";
		Env = [
			"HOME=/home/${user}"
			"USER=${user}"
			"NIX_PAGER=cat"
			"SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
			"NIX_CONF_DIR=/etc/nix"
			"NPM_CONFIG_PREFIX=/home/${user}/.npm-global"
			"PATH=/home/${user}/.npm-global/bin:/usr/bin:/bin"
		];
	};
}
