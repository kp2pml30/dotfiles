{ pkgs
, inputs
, lib
, config
, ...
}:
{
	services.xserver.videoDrivers = ["nvidia"];

	hardware.nvidia = {
		package = config.boot.kernelPackages.nvidiaPackages.beta;
		modesetting.enable = true;
		open = true;
		nvidiaSettings = true;
	};

	hardware.nvidia-container-toolkit.enable = true;
}
