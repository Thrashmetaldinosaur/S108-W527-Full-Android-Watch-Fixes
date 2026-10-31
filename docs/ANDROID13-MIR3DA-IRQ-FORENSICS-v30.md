# S108 Android 13 — exact-kernel MIR3DA IRQ forensics (V30)

**Status: offline reverse-engineering validated; no boot patch installed, no IRQ enabled.** Device: `uws6152_1h10_go`, Android 13, 4.14.98 vendor kernel with DA217 on I²C 2-0026. For tested physical-wake observations and safe-off state, see [DA217 testing history](ANDROID13-DA217-TWIST-TO-WAKE-TESTED.md).

## Method and integrity

Investigated the previously captured current-boot image, **without communicating with or changing the watch**. Extracted an uncompressed ARM64 kernel `Image` (17,381,384 bytes; SHA-256 `ea3b3be9e7bbb769631ee90727f3e52e8e9b71b80e77ded7fb5ab0ac62be8453`), then recovered and validated **88,703 compressed kallsyms names, offsets and all marker boundaries**. This permits exact code cross-references even though live `/proc/kallsyms` prints zeros.

**All hexadecimal locations below are raw, decompressed kernel `Image` offsets, NOT offsets in `boot.img` or runtime virtual addresses.** Never apply them blindly to an Android partition image.

## Fault 1 — incorrect power-management API in the IRQ worker

The exact kernel's workqueue function `mir3da_irq1_work` begins at `0x0056c074`. At **`0x0056c0c4`**, the AArch64 call `BL pm_runtime_force_resume` (`db c6 fb 97`, little-endian) targets `0x0045dc30`.

The exact same kernel's `pm_runtime_force_resume` calls **`pm_runtime_enable`** at `0x0045dcfc`. The DA217 probe already calls `pm_runtime_enable` at `0x0056c984`. The Linux runtime-PM source explicitly requires `pm_runtime_force_resume` to be paired with `pm_runtime_force_suspend` during *system* suspend/resume, not invoked once for each tilt IRQ. This directly explains the repeated **`Unbalanced pm_runtime_enable!`** warnings logged on physical-gesture attempts.

The worker's incorrect call can be proven from the exact firmware—not extrapolated from another device's driver. This does **not**, by itself, prove a PM usage counter leak.

## Fault 2 — reference-count imbalance is plausible

At `0x0056afb0`, `mir3da_irq1_handler` loads `W1=4` (`RPM_GET_PUT`) and at `0x0056afb4` calls `__pm_runtime_resume` (target `0x0045d1e8`), which acquires a runtime-PM usage reference. The immediate IRQ worker does **not** call `pm_runtime_put`, `__pm_runtime_idle`, or another obvious release of that same reference; instead it calls the unrelated force-resume helper.

Therefore the driver may accumulate runtime-PM references on repeated IRQs. The S108 does not expose `runtime_usage_count` in sysfs, so this is **a strong source-level concern, not a measured live leak**. A corrected implementation must pair every successfully acquired reference with a release, including failed workqueue submissions and error exits. A hard IRQ handler must not perform blocking PM operations unless specifically IRQ-safe.

## Fault 3 — IRQ rearm race

At **`0x0056c2a4`**, `mir3da_irq1_work` calls `enable_irq1` after its processing path. The `enable_irq1` helper checks an internal `irq_enabled` field at offset `0x188`. However the sysfs `irq1enable` store handler independently controls the *tilt enabled* state at offset `0x184`; the worker makes **no state check before rearming**. Thus queued work can re-enable IRQ after a concurrent sysfs disable, even if the user expected `echo 0 > irq1enable` to be final. This is especially concerning with the level-triggered active-low sensor line and earlier IRQ storms.

A correct design needs synchronization, cancellation or draining of outstanding work before confirming disable, a check of the desired tilt-enable state immediately before rearm, and explicit acknowledgement/deassertion of the DA217 interrupt source. The sensor's shorter `INT_LATCH=0xC9` reduced interrupts in earlier tests but **did not solve the driver**.

## Repair outline — not a flash recipe

1. In the IRQ handler, acquire a balanced runtime-PM reference using primitives appropriate for hard-IRQ context; if work scheduling fails, release the reference.
2. Resume/safely access the I²C device in process context; **replace the per-interrupt `pm_runtime_force_resume`** with the correctly paired workqueue PM operations.
3. On every worker exit, release its PM reference. Avoid races with system suspend.
4. Before rearming, check the synchronized desired tilt/IRQ-enable state. Deassert or clear the source; enforce a bounded one-shot/cooldown and fail closed if the line remains asserted.
5. Preserve original boot, recovery, AVB, Magisk and powered-off charging; only consider a signed candidate kernel after offline verification and explicit fail-safe rollback. Patching the one warning-producing call to a NOP would **not** fix PM reference counts, the rearm race or storm behavior.

## Current safe operating state

Do not set `irq1enable=1` persistently. Physical twist can wake the screen in bounded tests, and the native fullscreen glance plus on-watch uinput POWER screen-off are already individually verified (V19/V20/V27/V28). Complete unattended twist-to-wake remains unfinished.

The OCH1973 magnetic wake-source suspend issue found in V29 is separate and was **not modified** in this investigation.
