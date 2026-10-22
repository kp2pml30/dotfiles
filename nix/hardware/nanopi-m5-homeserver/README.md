# NanoPi M5 (RK3576) homeserver

Two configurations share `default.nix` (board bits: dtb, 1.5 Mbaud UART, networkd,
hung-task panic):

| Attribute | Module | Role |
| --- | --- | --- |
| `.#nanopi-m5` | `installed.nix` | deployed system, root on encrypted ZFS on NVMe |
| `.#nanopi-m5-sd` | `sd-image.nix` | bootable SD image, also the installer/rescue medium |

Boot chain: u-boot in SPI NOR -> extlinux on the ext4 `BOOT` partition -> systemd
initrd (DHCP + tailscaled + sshd) -> passphrase over ssh -> `rpool` import ->
switch-root.

`/boot` is ext4, not btrfs: u-boot's btrfs driver is read-only and barely
exercised on rockchip, and a misread there means UART-only recovery.

u-boot scans `mmc1 mmc0 nvme ...` in that order: with an SD card inserted the box
boots the SD image. Pull the card for normal operation, insert it to get rescue.

NVMe layout:

| Part | Label | Size | Content |
| --- | --- | --- | --- |
| 1 | `boot` | 4G | ext4 `BOOT`: kernels, initrds, initrd ssh/tailscale identities |
| 2 | `nanopi-m5-swap` | 32G | swap, dm-crypt with a random per-boot key |
| 3 | `rpool` | rest | ZFS, native `aes-256-gcm` + `zstd` |

## Before Reflashing the SD Card

The running system's identities live only on the old SD rootfs. Back them up on
mini (card in a reader, rootfs labelled `NIXOS_SD`):

```sh
sudo -v   # sudo and age would otherwise prompt on the same tty
sudo mount -o ro /dev/disk/by-label/NIXOS_SD /mnt
sudo tar -C /mnt -czf - \
	var/lib/secrets/main \
	etc/ssh/ssh_host_ed25519_key etc/ssh/ssh_host_ed25519_key.pub \
	var/lib/tailscale \
	| age -p > nanopi-m5-identity.tar.gz.age
sudo umount /mnt
```

| Path | Without it |
| --- | --- |
| `var/lib/secrets/main` | age identity behind `nix/secrets/keys/nanopi-m5.pub`; every secret has to be re-encrypted |
| `etc/ssh/ssh_host_ed25519_key*` | new host key, `known_hosts` entries break |
| `var/lib/tailscale` | new tailnet node and IP, the old one lingers in headscale |

## Check u-boot Sees the NVMe

Before partitioning: UART, interrupt autoboot, then

```
pci enum
nvme scan
nvme info
```

If the drive is missing, keep `BOOT` on the SD card instead and put only swap +
`rpool` on the NVMe.

## Install

Boot the SD image, then work on the NVMe (`$DISK`, a `/dev/disk/by-id/nvme-...`
path — *not* the SD card you booted from).

```sh
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+4G  -t1:8300 -c1:boot           "$DISK"
sgdisk -n2:0:+32G -t2:8200 -c2:nanopi-m5-swap "$DISK"
sgdisk -n3:0:0    -t3:BF00 -c3:rpool          "$DISK"
mkfs.ext4 -L BOOT "$DISK-part1"

# compression + encryption live here; the nix side only mounts what this creates
zpool create -f \
	-o ashift=12 -o autotrim=on \
	-O compression=zstd -O atime=off -O xattr=sa -O acltype=posixacl \
	-O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt \
	-O canmount=off -O mountpoint=none \
	rpool "$DISK-part3"

for ds in root nix var home; do zfs create -o mountpoint=legacy "rpool/$ds"; done
```

Swap needs no setup: `randomEncryption` formats it on every boot.

`installed.nix` addresses `BOOT` by filesystem UUID and swap by PARTUUID (the
filesystem UUID is wiped every boot). After repartitioning, update both from
`blkid`.

Keep the dataset list in sync with `kp2pml30.zfs.datasets`.

```sh
mount -t zfs rpool/root /mnt
mkdir -p /mnt/{boot,nix,var,home}
for ds in nix var home; do mount -t zfs "rpool/$ds" "/mnt/$ds"; done
mount /dev/disk/by-label/BOOT /mnt/boot
```

Restore the identities backed up above:

```sh
# on mini
age -d nanopi-m5-identity.tar.gz.age | ssh kp2pml30@<ip> sudo tar -C /mnt -xzpf -
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

Put the `.pub` into `nanopi-m5-initrd` in `nix/data/ssh-keys.nix`; clients pin it
from there.

Initrd tailnet node — likewise its own identity, enrolled once. Mint a single-use
key on vdsina (`headscale users list` for the ID):

```sh
sudo headscale preauthkeys create -u <id> -e 1h
```

then on the box:

```sh
install -d -m 700 /mnt/boot/initrd-tailscale
tailscaled --statedir=/mnt/boot/initrd-tailscale --socket=/run/ts-initrd.sock \
	--tun=userspace-networking --port=0 --no-logs-no-support &
tailscale --socket=/run/ts-initrd.sock up --login-server=https://wg.kp2pml30.moe \
	--hostname=nanopi-m5-initrd --auth-key=<key>
kill %1
```

`headscale nodes list` must show no expiry for `nanopi-m5-initrd`, or the unlock
path dies with it.

Install (build on mini, aarch64 via binfmt, so the box does not compile zfs):

```sh
# on mini
nix build .#packages.aarch64-linux.nanopi-m5-toplevel
nix copy --to ssh://kp2pml30@<ip> ./result
# on the box
nixos-install --system /nix/store/...-nixos-system-... --root /mnt --no-root-password
```

Then: `zpool export rpool`, power off, pull the SD card, boot.

## Deploying

From mini, over the tailnet; builds locally, pushes the closure, activates:

```sh
nixos-rebuild switch --flake .#nanopi-m5 \
	--target-host kp2pml30@nanopi-m5.ts.kp2pml30.moe --elevate sudo
```

Kernel or initrd changes take effect on the next reboot, which needs an unlock.

## Unlocking

The initrd sshd answers on port 22 on the LAN and, via the `nanopi-m5-initrd`
tailnet node, on the tailnet, with the key above, so the fingerprint differs from
the booted system's. `nix/personal/ssh-hosts.nix` pins it and defines the
`nanopi-boot` alias:

```sh
ssh nanopi-boot                          # tailnet
ssh -o HostName=<lan-ip> nanopi-boot     # LAN
```

Client needs OpenSSH >= 9.9 (`mlkem768x25519-sha256`) or >= 9.0
(`sntrup761x25519`): `nix/common.nix` allows nothing else.

The only ssh user is `boot-unlocker` (uid/gid in `nix/data`): it gets a
passphrase prompt and nothing else — no shell, no commands, no forwarding. A
root-owned socket service hands the passphrase to the `rpool` ask-password
request only and reports back. Tries are unlimited, with a 2 s doubling to 60 s
wait after each wrong one (`zfs-load-key-rpool` in `nix/zfs.nix`, replacing
nixpkgs' 3-try loop). The local console prompt stays available in parallel.

`installed.nix` sets `kp2pml30.zfs.initrd-ssh.rootDebugShell = true`: root gets
a bash shell with the same keys (`ssh -o HostKeyAlias=nanopi-m5-initrd
root@<ip>`), see Recovery.

The tailnet path needs a sane clock for TLS to headscale: the initrd loads the
hym8563 RTC driver, so it depends on the RTC battery. Without one, fall back to
the LAN or the console.

## Threat model

Encryption covers a powered-off disk leaving the flat. It does not cover an evil
maid: `/boot` and the SPI u-boot are unauthenticated, so anyone with physical
access can plant an initrd that keeps the legitimate host key and forwards the
passphrase.

`/boot` also holds the `nanopi-m5-initrd` tailnet key in the clear: a stolen disk
joins the tailnet. Headscale has no ACL policy, so that node reaches every peer;
delete it in headscale (`headscale nodes delete -i <id>`) if the box goes missing.

## Recovery

From the initrd root shell, without the SD card: unlock as usual in a second
session, or stop before switch-root and work on `/sysroot`. `/boot` is mounted
read-only; after editing `extlinux.conf`, `umount /boot` before rebooting —
u-boot does not replay the ext4 journal and would read the old file. A one-off
kernel parameter goes on the `APPEND` line of `LABEL nixos-default`.

`panfrost` is blacklisted: its probe sometimes hangs the SoC right after the gpu
power domain fails to ack, a few seconds into stage 2.

Otherwise insert the SD card, boot, and:

```sh
# add -f only after confirming nothing else has the pool imported
zpool import -R /mnt rpool && zfs load-key -a
# ...
zpool export rpool   # before pulling the card, or the next NVMe boot may need -f
```

The SD image has no `var/lib/secrets/main`, so it does not join the tailnet:
LAN or UART only.

Rolling back a bad generation needs the UART (1.5 Mbaud, CP2102/FT232/CH340 — a
Flipper bridge tops out at 921600) to pick another extlinux entry.
