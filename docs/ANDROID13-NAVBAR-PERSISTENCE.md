# S108 / W527 Android 13: persistent 36dp navbar (Magisk v10 service)

**Verified October 29, 2026 on one S108 (Unisoc uws6152_1h10_go, crDroid Android 13, Magisk 30.7).**

This is a **navbar-only userspace modification**, independent of [normal-boot Magisk root and powered-off charging](ANDROID13-NORMAL-BOOT-MAGISK-CHARGING.md). It does not modify boot, AVB, misc, recovery, modem or charger firmware.

## Result: reboot-confirmed

| Resource | Original | Verified compact result |
| --- | --- | --- |
| `android:dimen/navigation_bar_height` | 48dp | **36dp** |
| `android:dimen/navigation_bar_frame_height` | 48dp | **36dp** |
| `com.android.systemui:dimen/navigation_key_width` | 80dp | **60dp** |
| Statusbar left/right inset (separate module) | 8dp / 8dp | **28dp / 16dp, unchanged by navbar fix** |

The existing older `s108_navbar_compact` Magisk module remained **disabled**, the active `s108_compact_navbar_boot` Magisk module remained **enabled**, and the independent `s108_statusbar_insets` module remained **enabled**.

The automatic v10 test measured these checkpoints following one normal reboot:

1. Checks 1–2: 48/48/80dp and 8/8dp (initial Android resources).
2. Check 3: navbar still 48/48/80dp; statusbar independently restored to 28/16dp.
3. **Checks 4 and 5: navbar 36/36/60dp and statusbar 28/16dp**. User visually confirmed the fix.

The on-watch Magisk log proves the service was executed: Android boot completed at **14:37:43**; first attempt at **14:38:03** partially failed; second at **14:38:28** succeeded and refreshed SystemUI once at **14:38:32–33**. The service exited normally. **This is confirmation across one reboot, not a long-term study or validation on other firmware.**

## Root cause of failures in v7/v9

The fabricated numeric overlays themselves were correct. Running them manually from ADB/root produced 36/36/60dp. However, the v7 and v9 **Magisk boot services** repeatedly failed with:

```text
cmd: Failure calling service overlay: Failed transaction (2147483646)
```

Changing the wait from 25 seconds to 45 seconds did **not** cure the issue; seven v9 retries, including direct shell execution and `su -c`, failed the same way.

**Fix:** Inside the Magisk boot service, each **Binder-facing** `cmd overlay` subprocess must explicitly redirect all three inherited standard file descriptors to `/dev/null`:

```sh
cmd overlay fabricate --target android --name s108compact_height \
  android:dimen/navigation_bar_height 0x05 0x2401 \
  </dev/null >/dev/null 2>&1
cmd overlay enable --user 0 com.android.shell:s108compact_height \
  </dev/null >/dev/null 2>&1
```

The `cmd` process may pass its inherited file descriptors to `system_server`. Under this Magisk/Android combination, forwarding descriptors inherited from Magisk's logging context provoked Binder transaction failures. Redirecting the **individual `cmd overlay` subprocesses** solved the observed problem. Logging around those commands remains safe; avoid redirecting the Binder-facing command's own stdout/stderr to the module log.

The [exact, device-tested v10 apply script](../modules/s108_compact_navbar_boot/apply.sh) implements that redirection for all three resource overlays. Its exit codes are logged by the [v10 boot service](../modules/s108_compact_navbar_boot/service.sh).

## How the persistent module operates

- Root-owned Magisk module: `/data/adb/modules/s108_compact_navbar_boot`.
- Entry point: **`service.sh`**, invoked by Magisk `late_start service`. No SystemUI replacement APK.
- Wait for `sys.boot_completed=1` (timeout after up to 240 seconds).
- Delay **20 seconds**, then apply navbar resources.
- Retry every **20 seconds**, up to **five attempts**, exiting at the first successful apply.
- After success, restart `com.android.systemui` **once** to load the new dimensions, then exit. No resident background watchdog.
- Boot log: `/data/adb/modules/s108_compact_navbar_boot/boot-v10.log`.

The compact resource values are encoded via `cmd overlay fabricate`:

```text
android:dimen/navigation_bar_height                  0x05 0x2401   (36dp)
android:dimen/navigation_bar_frame_height            0x05 0x2401   (36dp)
com.android.systemui:dimen/navigation_key_width      0x05 0x3C01   (60dp)
```

The module intentionally **does not touch** statusbar padding or alignment.

### Source and integrity

The two published shell files reproduce the **exact byte lengths** and observed SHA-256 hashes of the successful on-device scripts:

| File | SHA-256 on tested device |
| --- | --- |
| [`service.sh`](../modules/s108_compact_navbar_boot/service.sh) | `4fbe7647248e989d6fd247863d3c894f648e5125485ed43ced31f2e980809dd0` |
| [`apply.sh`](../modules/s108_compact_navbar_boot/apply.sh) | `6928a8c2934bc45726f2e2594102c9f710493d45a1be66fa01548a669624bc3c` |

The current device retained the module metadata **version 7.0** because v10 was a **script-only upgrade of that existing module**, not a new Magisk module installation. The published `module.prop` reflects the tested installed module. It should not be read as a v7 solution to the Binder problem: the **v10 service/apply scripts** are the operative fix.

### Reproducing on a prepared S108

The **tested workflow** updated the **existing** `s108_compact_navbar_boot` module after full local hashes and device/module preflight. It also **kept backups** before changing only `service.sh` and `apply.sh`. A first-time installation on another S108 was **not** tested.

Before adapting the workflow:

1. Verify Android 13, Magisk 30.7 root and board `uws6152_1h10_go`. Verify that no other script already modifies these resources during startup.
2. Preserve the existing `module.prop`, `service.sh`, `apply.sh`, `uninstall.sh` and any `disable` markers. Do **not** disable the separate `s108_statusbar_insets` module.
3. Transfer the exact source scripts to `/data/local/tmp` and verify their SHA-256 there. When writing to `/data/adb/modules`, use **`adb shell su -c /path/to/prepared-root-script.sh`**, NOT `su 0`, which hung in testing on this watch. Do not run root-managed module-file checks from ordinary unprivileged ADB.
4. Back up the old module scripts, atomically replace only the two files, retain executable permission (`0755`) and root ownership, then verify full SHA-256 via `su -c`. The original tested backup names were `service-v9.v10bak` and `apply-v7.v10bak`.
5. Verify overlays on the current boot, reboot **once**, and verify repeated 36/36/60dp readings plus unchanged 28/16dp statusbar values. Do **not** claim success merely because the script was installed.
6. Review `boot-v10.log` for `NAVBAR_V10_SERVICE_SUCCESS`. If it fails, retain logs and do not blindly reboot or reinstall repeatedly.

The [module source directory](../modules/s108_compact_navbar_boot/) can be used as reference for a device-specific installation. **No portable binary installer or universal flashable image is claimed here.** Magisk root and writable /data/adb are prerequisites.

## Rollback

The tested installation preserved the previous service as `service-v9.v10bak` and previous apply script as `apply-v7.v10bak` inside the same module directory. For a failed installation, restore the **matching original files from the same watch**, with correct owner, permissions and hashes. Do not touch `s108_statusbar_insets`, boot, AVB, misc, recovery or system partitions.

To disable only the navbar module, Magisk's module manager or the corresponding `disable` marker may be used, with a controlled reboot. The optional [`uninstall.sh`](../modules/s108_compact_navbar_boot/uninstall.sh) disables only the three `com.android.shell:s108compact_*` overlays; it does **not** modify the status bar.

## Known limits

- One device, one demonstrated post-update reboot, two consecutive successful post-boot dimension checks.
- The first overlay attempt during the successful reboot had a temporary frame-related failure; the second attempt succeeded. Retries matter.
- Users with a different crDroid/SystemUI build, Magisk version or base overlay configuration must validate compatibility and keep rollback copies.
- No firmware flashing, physical USB reconnection or userdata wipe is needed for this userspace fix.
