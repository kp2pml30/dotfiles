# QEMU VM Nix Store Sharing Plan

## Goal

VM should have:
1. Read-only access to host's `/nix/store` with a local writable overlay
2. Host can download packages from substituters (cachix, etc.) for the VM
3. VM cannot push anything back to the host's store

## Recommended Approach: 9p RO share + OverlayFS + nix-serve

Three components working together:

### 1. 9p share — host exposes `/nix/store` read-only

Add to QEMU args in `scripts/run-claude-vm.sh`:
```bash
-virtfs local,path=/nix/store,security_model=none,mount_tag=nix-store,readonly=on
```

### 2. OverlayFS in guest — RO lower (host store) + RW upper (local tmpfs/disk)

In `nix/hardware/claude-vm.nix`:
```nix
boot.initrd.availableKernelModules = [ ... "9p" "9pnet" "9pnet_virtio" "overlay" ];

fileSystems."/nix/.ro-store" = {
  device = "nix-store"; fsType = "9p";
  options = [ "trans=virtio" "version=9p2000.L" "cache=loose" "ro" ];
  neededForBoot = true;
};
fileSystems."/nix/.rw-store" = {
  device = "tmpfs"; fsType = "tmpfs";
  options = [ "mode=0755" "size=4G" ];
  neededForBoot = true;
};
fileSystems."/nix/store" = {
  device = "overlay"; fsType = "overlay";
  options = [ "lowerdir=/nix/.ro-store" "upperdir=/nix/.rw-store/store" "workdir=/nix/.rw-store/work" ];
  depends = [ "/nix/.ro-store" "/nix/.rw-store" ];
  neededForBoot = true;
};
```

### 3. nix-serve on host — so the VM's Nix DB knows about host paths

On host (add to host NixOS config):
```nix
services.nix-serve = {
  enable = true;
  port = 5000;
  secretKeyFile = "/etc/nix/secret-key";
};
```

Generate signing key first:
```bash
nix-store --generate-binary-cache-key myhost-1 /etc/nix/secret-key /etc/nix/public-key
```

In VM (`nix/claude-vm/default.nix`):
```nix
nix.settings = {
  substituters = [ "http://10.0.2.2:5000" "https://cache.nixos.org" ];
  trusted-public-keys = [ "myhost-1:<public-key-from-above>" "cache.nixos.org-1:..." ];
};
```

`10.0.2.2` is the host IP in QEMU user-mode networking.

## How Requirements Are Met

| Requirement | Mechanism |
|---|---|
| RO access to host store + local overlay | 9p `readonly=on` + OverlayFS — VM reads host paths, writes go to upper layer only |
| Host downloads from substituters for VM | Host runs `nix build` normally; nix-serve auto-exposes everything in host store |
| VM can't push to host store | 9p is read-only at QEMU level; nix-serve is read-only by design |

## Key Caveat: Nix DB vs Filesystem

The OverlayFS gives zero-copy file access, but Nix's SQLite DB in the VM won't automatically know about host paths. nix-serve solves this — the VM "discovers" paths via the binary cache protocol, and since the actual files are already present via the overlay, there's no actual download (just DB registration).

## Alternative: Experimental `local-overlay-store`

Nix >=2.19 has `local-overlay-store` (gated behind `extra-experimental-features = local-overlay-store`) that handles DB merging natively without nix-serve. Not stable yet.

## Files to Modify

- `scripts/run-claude-vm.sh` — add `-virtfs` arg
- `nix/hardware/claude-vm.nix` — add kernel modules + overlay mounts
- `nix/claude-vm/default.nix` — add substituter config
- Host NixOS config — enable `nix-serve`

## Reference

- NixOS `qemu-vm.nix` module uses this same pattern
- `microvm.nix` project uses this same pattern
- Nix docs: https://nix.dev/manual/nix/2.30/store/types/experimental-local-overlay-store
- nix-serve: https://github.com/edolstra/nix-serve
