{ pkgs
, inputs
, ...
}:
{
	imports = [
		inputs.nixos-wsl.nixosModules.default
	];
	wsl = {
		enable = true;
		defaultUser = "kp2pml30";
		wslConf.interop.appendWindowsPath = false;
	};
}
