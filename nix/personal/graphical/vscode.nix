{ pkgs
, lib
, rootPath
, config
, ...
}:
let
	cfg = config.kp2pml30;
in lib.mkIf cfg.vscode {
	home-manager.users.${cfg.username} = {
		programs.vscode = {
			enable = true;
			package = pkgs.vscode;
			mutableExtensionsDir = false;
			userSettings = lib.importJSON("${rootPath}/vscode/settings.json");
			extensions = with pkgs; [
				vscode-extensions.eamodio.gitlens
				vscode-extensions.editorconfig.editorconfig

				vscode-extensions.bierner.markdown-mermaid

				vscode-extensions.tamasfe.even-better-toml

				vscode-extensions.streetsidesoftware.code-spell-checker
				(pkgs.vscode-utils.buildVscodeMarketplaceExtension {
					mktplcRef = {
						name = "code-spell-checker-russian";
						publisher = "streetsidesoftware";
						version = "0.2.2";
						sha256 = "a3b00c76a4aafecb962d6c292a3b9240a27d84b17de2119bb8007d0ad90ab443";
					};
					meta = {
						license = lib.licenses.mit;
					};
				})
			];
		};
	};
}
