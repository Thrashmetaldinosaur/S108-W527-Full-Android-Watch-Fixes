# S108 navbar v10: historical upgrade helpers (device-tested)

These are the **exact watch-side helper scripts** from the October 29, 2026 successful `s108_compact_navbar_boot` v9 → v10 patch. The actual v10 `service.sh` and `apply.sh` are already published at [`modules/s108_compact_navbar_boot/`](../../modules/s108_compact_navbar_boot/). See [the verified navbar guide](../../docs/ANDROID13-NAVBAR-PERSISTENCE.md).

**This is NOT a first-time installer.** It deliberately refuses to run unless the watch already has the matching *older* v9 module, the legacy navbar module is disabled, the separate working status-bar module is enabled, Android is 13, and board is `uws6152_1h10_go`. Do **not** run it on a watch where navbar v10 already works. Do **not** remove its preflight checks to force installation on another firmware or Magisk version.

## Files as used in the successful run

| File | SHA-256 of tested source | Purpose |
| --- | --- | --- |
| [`install-device.sh`](install-device.sh) | `5814ad6d3510601f47a5f9419b31c4f760e7d6e84796bdb84534621fa68de48b` | Checks board/module state, preserves old scripts, replaces only navbar `service.sh` and `apply.sh` |
| [`collect-device.sh`](collect-device.sh) | `eba8b3fba7f569d070cdb820dba3592ec1d567d7edc30c6692d70739518b2aa8` | Reports module states, hashes, and navbar/statusbar boot logs |
| [`restore-device.sh`](restore-device.sh) | `ffa52eb45eb0c1bf6f7e0d159fd2b3b4567bf503b96c89d0288f314e01f4b6dd` | *Manual* restoration of preserved v9/v7 scripts; not an automatic rollback |
| [v10 `service.sh`](../../modules/s108_compact_navbar_boot/service.sh) | `4fbe7647248e989d6fd247863d3c894f648e5125485ed43ced31f2e980809dd0` | Reboot-persistent service using Binder-safe descriptors |
| [v10 `apply.sh`](../../modules/s108_compact_navbar_boot/apply.sh) | `6928a8c2934bc45726f2e2594102c9f710493d45a1be66fa01548a669624bc3c` | Recreates the 36/36/60dp navbar overlays |

The original successful PowerShell orchestrator contained a user-specific ADB executable path and device serial, so it is **not** published unchanged. The five watch-side scripts above were transferred with SHA-256 verification, and only the two module scripts were replaced. The public repository does not contain the device's private logs, signing keys, or boot images.

## Original guarded workflow (for qualified maintainers)

**Prerequisite:** ADB connectivity, working Magisk `su -c`, the original matching v9 module with service SHA-256 `2fa01aa7dacb5eb55522f2110764354c8d3b63470301c73e471cd58707b39913`, and a verified backup/rollback route. This script is intentionally not adaptable by skipping guards.

Run from the root of a locally cloned repository, using the correct ADB executable and selected watch:

```sh
adb shell mkdir -p /data/local/tmp/s108_navbar_v10
adb push modules/s108_compact_navbar_boot/service.sh /data/local/tmp/s108_navbar_v10/service-v10.sh
adb push modules/s108_compact_navbar_boot/apply.sh /data/local/tmp/s108_navbar_v10/apply-v10.sh
adb push scripts/navbar-v10-upgrade/install-device.sh /data/local/tmp/s108_navbar_v10/install-device.sh
adb push scripts/navbar-v10-upgrade/collect-device.sh /data/local/tmp/s108_navbar_v10/collect-device.sh
adb push scripts/navbar-v10-upgrade/restore-device.sh /data/local/tmp/s108_navbar_v10/restore-device.sh
adb shell 'chmod 0755 /data/local/tmp/s108_navbar_v10/*.sh'
adb shell sha256sum /data/local/tmp/s108_navbar_v10/service-v10.sh /data/local/tmp/s108_navbar_v10/apply-v10.sh
```

Before applying, compare **every local and on-watch SHA-256** against the table, verify that `su -c id` returns root, that the existing module matches the expected *pre-v10* hash, and confirm the separate status bar reads 28dp left / 16dp right. The successful orchestrator also ran the new apply script manually and validated 36dp / 36dp / 60dp before changing the boot service. **Do not skip that live validation or reboot merely because staging succeeded.**

After all these safeguards pass:

```sh
adb shell su -c /data/local/tmp/s108_navbar_v10/install-device.sh
adb shell su -c /data/local/tmp/s108_navbar_v10/collect-device.sh
```

Only after an explicit safe-install result and verified installed hashes, perform **one deliberate normal reboot** and check:

```sh
adb shell su -c /data/local/tmp/s108_navbar_v10/collect-device.sh
adb shell cmd overlay lookup --user 0 android android:dimen/navigation_bar_height
adb shell cmd overlay lookup --user 0 android android:dimen/navigation_bar_frame_height
adb shell cmd overlay lookup --user 0 com.android.systemui com.android.systemui:dimen/navigation_key_width
```

On the tested S108, the first boot-service attempt briefly failed, then the second restored 36dp/36dp/60dp. The separate statusbar module restored 28dp/16dp. Verify stable readings twice, not just the existence of files. Keep the existing module backups `service-v9.v10bak` and `apply-v7.v10bak`.

**If a partial install or unexpected hash occurs, STOP.** Do not reinstall, reboot repeatedly, or reuse the original service hash assertion on an already-patched module. Use device-specific backups and the historical [rollback helper](restore-device.sh) only when you have confirmed matching backup files. Rollback restores the older scripts that were known to have persistence problems; it does not modify boot partitions or the separate status bar module.

## What this does not cover

This procedure is unrelated to LTE, lift-to-wake, thermal tuning, boot/recovery/AVB, or powered-off charging. The DA217 tilt interrupt work was experimental and is **not** a verified permanent fix; it is intentionally not published as one.
