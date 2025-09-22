{ pkgs
, inputs
, lib
, config
, ...
}:
{
	services.xserver.videoDrivers = ["nvidia"];

	hardware.nvidia = {
		package = config.boot.kernelPackages.nvidiaPackages.production;
		modesetting.enable = true;
		open = false;
		nvidiaSettings = true;
	};
}
