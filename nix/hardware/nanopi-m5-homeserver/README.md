# NanoPi M5 (RK3576) homeserver

Two configurations share `default.nix` (board bits: dtb, 1.5 Mbaud UART, networkd,
hung-task panic):

| Attribute | Module | Role |
| --- | --- | --- |
| `.#nanopi-m5` | `installed.nix` | deployed system, root on encrypted ZFS |
| `.#nanopi-m5-sd` | `sd-image.nix` | bootable SD image, also the installer/rescue medium |

Boot chain: u-boot in SPI NOR -> extlinux on the ext4 `BOOT` partition -> systemd
initrd (DHCP + sshd) -> passphrase over ssh -> `rpool` import -> switch-root.

`/boot` is ext4, not btrfs: u-boot's btrfs driver is read-only and barely
exercised on rockchip, and a misread there means UART-only recovery.

## Install

Boot the SD image, then work on the target disk (`$DISK`, a `/dev/disk/by-id/...`
path — *not* the SD card you booted from).

```sh
sgdisk --zap-all "$DISK"
sgdisk -n1:16M:+2G -t1:8300 -c1:boot "$DISK"   # 16M gap keeps an SD u-boot at sector 64 possible
sgdisk -n2:0:0     -t2:BF00 -c2:rpool "$DISK"
mkfs.ext4 -L BOOT "$DISK-part1"

# compression + encryption live here; the nix side only mounts what this creates
zpool create -f \
	-o ashift=12 -o autotrim=on \
	-O compression=zstd -O atime=off -O xattr=sa -O acltype=posixacl \
	-O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt \
	-O canmount=off -O mountpoint=none \
	rpool "$DISK-part2"

for ds in root nix var home; do zfs create -o mountpoint=legacy "rpool/$ds"; done
```

Keep the dataset list in sync with `kp2pml30.zfs.datasets`.

```sh
mount -t zfs rpool/root /mnt
mkdir -p /mnt/{boot,nix,var,home}
for ds in nix var home; do mount -t zfs "rpool/$ds" "/mnt/$ds"; done
mount /dev/disk/by-label/BOOT /mnt/boot
```

Initrd ssh host key — generated on the box and never entering the nix store,
which is world-readable and gets pushed to the binary cache. It is a
boot-time-only identity, distinct from the running system's host key:

```sh
mkdir -p /mnt/boot/initrd-ssh
ssh-keygen -t ed25519 -N "" -C nanopi-m5-initrd \
	-f /mnt/boot/initrd-ssh/ssh_host_ed25519_key
chmod 600 /mnt/boot/initrd-ssh/ssh_host_ed25519_key
```

Copy the `.pub` off the box now — it is what you pin in `known_hosts` below.

Install (build on mini, aarch64 via binfmt, so the box does not compile zfs):

```sh
# on mini
nix build .#packages.aarch64-linux.nanopi-m5-toplevel
nix copy --to ssh://kp2pml30@<ip> ./result
# on the box
nixos-install --system /nix/store/...-nixos-system-... --root /mnt --no-root-password
```

## Unlocking

The initrd sshd answers on port 22 with the key above, so the fingerprint differs
from the booted system's. Give it its own `known_hosts` entry, and pin it from the
`.pub` generated during the install rather than accepting it TOFU — a forged
fingerprint gets the pool passphrase:

```sh
# on the client, from the .pub copied off the box during install
echo "nanopi-m5-initrd $(cat ssh_host_ed25519_key.pub)" >> ~/.ssh/known_hosts
```

```
Host nanopi-boot
	HostName <ip>
	User root
	HostKeyAlias nanopi-m5-initrd
```

Client needs OpenSSH >= 9.9 (`mlkem768x25519-sha256`) or >= 9.0
(`sntrup761x25519`): `nix/common.nix` allows nothing else.

`ssh nanopi-boot` drops straight into the passphrase prompt
(`systemd-tty-ask-password-agent`). `ssh nanopi-boot <cmd>` still gets a shell for
debugging. The local console prompt stays available in parallel.

## Threat model

Encryption covers a powered-off disk leaving the flat. It does not cover an evil
maid: `/boot` and the SPI u-boot are unauthenticated, so anyone with physical
access can plant an initrd that keeps the legitimate host key and forwards the
passphrase.

## Recovery

Boot the SD image and:

```sh
# add -f only after confirming nothing else has the pool imported
zpool import -R /mnt rpool && zfs load-key -a
```

Rolling back a bad generation needs the UART (1.5 Mbaud, CP2102/FT232/CH340 — a
Flipper bridge tops out at 921600) to pick another extlinux entry.
