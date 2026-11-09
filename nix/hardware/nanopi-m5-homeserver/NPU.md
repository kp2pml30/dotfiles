# RK3576 NPU On The NanoPi M5

State as of 2026-11-09. The NPU is off on this board

## Failed Attempt (2026-11-03)

Setup: mainline 6.18.55, Kiln (`gahingwoo/kiln` rev `41309b74`) patches 0001-0009, vendor `rknpu` 0.9.8, tested by `kexec -c --dtb` under a watchdog. Overlay:

```dts
&vdd_npu_s0 { regulator-always-on; };
&rknpu { rknpu-supply = <&vdd_npu_s0>; status = "okay"; };
&rknpu_mmu_0 { status = "okay"; };
&rknpu_mmu_1 { status = "okay"; };
```

| Test | Rail pinned | NPU + IOMMUs | Result |
|---|---|---|---|
| 1 | Yes | Enabled | Wedge before userspace, watchdog reset at ~110 s |
| 2 | No | Disabled | Boots |
| 3 | Yes | Disabled | Boots, `vdd_npu_s0` at 750 mV |

- The cause is unknown: there is no log of the wedge, and test 1 ran once
- Never tested: cold boot of the NPU DT, `mmu_0` vs `mmu_1` split, individual patches, unpatched kernel with IOMMUs enabled

### Leading Hypothesis (Unverified)

1. `rockchip-iommu` probe powers on `npu0`, and Kiln 0009 then does unconditional MMIO to `0x27700000` in `rockchip_pd_power()`
2. Kiln 0006 turns failed `mem_reset` polls into warnings, removing the abort that would stop power-on
3. Nothing orders `vdd_npu_s0` before that probe: the live DT has no `domain-supply`, and `DOMAIN_RK3576` on 6.18 has no regulator parameter
4. The parent kernel of test 1 logged `vdd_npu_s0: disabling` 5 min before the `kexec`, so the rail was off on entry

Test 3 does not clear this: it shows the rail is fine by userspace, not at IOMMU probe. Whether RK806 registers before IOMMU probe is unmeasured

Other differences from Kiln's tested setup: Kiln was verified on 7.1.3, on a Radxa ROCK 4D, with Armbian's firmware; this board runs 6.18.55 and rkbin BL31 v1.20

### Next Test

Kexec into the NPU DT from a kernel booted with the rail pinned, which removes the rail-off-on-entry variable. A boot implicates ordering; a wedge excludes the rail and leaves the `mmu_0`/`mmu_1` split and dropping 0009

Getting a log needs a USB-UART adapter (1.5 Mbaud, 3.3 V) or a kernel with `PSTORE_RAM` and `NETCONSOLE` built in; both are `=m` here

## Upstream Path

Waiting on `[PATCH v16 00/16] accel/rocket: RK3576 NPU (RKNN) enablement` by Jiaxing Hu, posted 2026-11-08, based on `next-20261105`. It replaces Kiln's vendor stack with the mainline `accel/rocket` driver, merged for RK3588 in 6.18

| Part | Patches | Status |
|---|---|---|
| IOMMU clocks, stale faults | `841363ebb508`, `b10d5920cafa` (outside v16) | In `linux-next` since `next-20260727` |
| Power domain settle delay, reset cycling | 9-10 | Pending; Ulf Hansson offered to take them |
| Bindings | 6-8 | Pending |
| Driver | 1-5, 11-13 | Pending, through accel |
| RK3576 and ROCK 4D DT | 14-16 | Pending, through Rockchip |

Nothing from the RK3576 work is in Linus' tree, and no target release is stated

### Still Needed After Merge

1. **M5 board DT:** v16 enables only `rk3576-rock-4d`. Leonard Lausen ran v14 on an M5 and posted a board patch on top of it; it is not in the series and has not been reviewed here
2. **Userspace:** `charsiu` is the open LLM runtime on `rocket`; Llama-3.2-1B runs at 17.85-18.60 tokens/s. Mesa Teflon needs `mesa!43804`, open with no review, covering 1 regular convolution type only
3. **Rail voltage or clock:** On the ROCK 4D, 2 cores at 786 MHz and 750 mV give wrong words; fixes are 594 MHz or 800 mV. This M5 measured 750 mV, so the same limit may apply

### Relevance To The Failure

- v16 16/16 sets `vdd_npu_s0` as the NPU `domain-supply`, the dependency missing here. Whether 6.18's missing regulator parameter is addressed by the series is unchecked
- Kiln's arming MMIO (0009) is absent from the v16 patch titles; the diffs were not read
- The 15 µs settle delay is not the suspect: Kiln 0001 already has it. Upstream reports 0 µs causes an async SError even with the rail always on, and 15 µs gave 536 clean cold power-ons
- Known upstream issue: the IOMMU does not recover after repeated resets with a 2 ms job timeout

Status details for patches 10-16 come from a generated summary of the thread, not from reading them

## Sources

- [linux-rk3576-npu](https://github.com/gahingwoo/linux-rk3576-npu)
- [v16 thread](https://ratatoskr.run/dri-devel/2026/11/17891589/t)
- [IOMMU patches applied](https://lkml.iu.edu/2607.3/03481.html)
- [charsiu](https://github.com/gahingwoo/charsiu)
- [Kiln](https://github.com/gahingwoo/kiln)
