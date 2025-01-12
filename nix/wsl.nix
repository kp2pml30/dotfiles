{ pkgs
, inputs
, rootPath
, ...
}:
{
	imports = [
		inputs.nixos-wsl.nixosModules.default
		#inputs.vscode-server.nixosModules.default
	];
	wsl = {
		enable = true;
		defaultUser = "kp2pml30";
		wslConf.interop.appendWindowsPath = false;
	};

	#services.vscode-server.enable = true;
	#home-manager.users.kp2pml30.home.file.".vscode-server/server-env-setup" = {
	#	enable = false;
	#	executable = true;
	#	text = builtins.readFile("${rootPath}/nix/wsl/vscode-patch.sh");
	#};
}
