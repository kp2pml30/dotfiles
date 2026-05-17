{ buildUBoot, lib }:

let
	rkbin = builtins.fetchGit {
		url = "https://github.com/rockchip-linux/rkbin.git";
		# Bumped from 9b6f766 (DDR v1.03 / BL31 v1.04): the v1.03 DDR blob is
		# unproven on this board, while DDR v1.09 / BL31 v1.20 was confirmed to
		# train the 16GB LPDDR5 NanoPi M5 over maskrom USB.
		rev = "74213af1e952c4683d2e35952507133b61394862";
		shallow = true;
	};
in
buildUBoot {
	defconfig = "nanopi-m5-rk3576_defconfig";

	# Debug UART is hardwired to 1.5 Mbaud by the rk3576 boot ROM and rkbin TPL/SPL.
	# Use a USB-UART adapter that supports 1500000 (CP2102/FT232/CH340) — Flipper's
	# bridge tops out at 921600 and will not work.

	extraMakeFlags = [
		"BL31=${rkbin}/bin/rk35/rk3576_bl31_v1.20.elf"
		"ROCKCHIP_TPL=${rkbin}/bin/rk35/rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.09.bin"
	];

	# u-boot-rockchip.bin     -> SD/eMMC layout (idbloader+itb at sector 64)
	# u-boot-rockchip-spi.bin -> SPI NOR layout (CONFIG_ROCKCHIP_SPI_IMAGE).
	# The RK3576 BootROM reads SPI reliably and before SD, so SPI boot
	# sidesteps the BootROM's inability to init the 256GB SDXC card.
	filesToInstall = [ "u-boot-rockchip.bin" "u-boot-rockchip-spi.bin" ];
}
