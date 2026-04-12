{ config
, pkgs
, lib
, ...
}:
let
	cfg = config.kp2pml30;
in {
	options.kp2pml30.qemu = lib.mkEnableOption "";

	config = lib.mkIf cfg.qemu {
		environment.systemPackages = with pkgs; [
			qemu
			OVMF
		];

		virtualisation.libvirtd.enable = true;

		users.users.${cfg.username}.extraGroups = [ "libvirtd" ];
	};
}
