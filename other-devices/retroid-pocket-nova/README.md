# Retroid Pocket Nova — M1/M2 to L2/R2 permanent trigger replacement (Magisk v3)

> **For the Retroid Pocket Nova only, not the S108/W527 watch.** This independent project is stored under `other-devices/` because this account does not yet have a dedicated Nova repository.

## Confirmed working — November 7, 2026

A flat-back Retroid Pocket Nova with the original physical L2/R2 triggers removed can use its rear **M1/M2** buttons in their place. A tested, reversible Magisk v3 module provides normal digital L2/R2 button events **and** full-pressure analog trigger-axis events to Android apps.

**Device-tested after reboot:** GameNative and an independent Android gamepad tester recognize M1 as L2 and M2 as R2. Retroid's built-in keypad tester continues showing M1/M2: it identifies the physical buttons, not the translated app-facing input. No GameNative-specific profiles or paid remapper are needed.

| Physical input | Linux event (M buttons in Retroid **Default** mode) | Android output |
| --- | --- | --- |
| M1 | `BTN_C`, code **306** | `BUTTON_L2` + `LTRIGGER` full pressure while held |
| M2 | `BTN_Z`, code **309** | `BUTTON_R2` + `RTRIGGER` full pressure while held |

The Nova exposes an **Xbox Wireless Controller**, vendor/product **2022:3002**. Its original trigger axes are `ABS_BRAKE` (code 10) and `ABS_GAS` (code 9), range 0–32767.

## How the fix works

1. A device-specific Android `Vendor_2022_Product_3002.kl` layout maps codes 306/309 to `BUTTON_L2`/`BUTTON_R2`, and aliases the native axis inputs to `LTRIGGER`/`RTRIGGER`.
2. A small root boot service observes **the same existing gamepad** at `/dev/input/eventN`, including raw events and held-key state. Presses on M1/M2 inject full-scale `ABS_BRAKE`/`ABS_GAS` (32767), releases write zero. There is no second virtual gamepad.
3. Magisk mounts the replacement layout systemlessly; stock partitions and controller firmware are not flashed.

**This is an Android/Linux input-layer replacement, not a hardware firmware modification.**

## Installation prerequisites

- Retroid Pocket Nova, rooted with Magisk (tested with Magisk 31.1 and stock Android 13)
- Rear M1/M2 set to **Default** in Retroid Handheld Settings
- Working `adb` connection over USB or Wi-Fi
- Exact device identity checked before applying any module

**Repository status:** The working source and instructions are published here, but the compiled installable Magisk ZIP is **not yet uploaded to GitHub**. Do not attempt to install the source folder as a Magisk module. The verified binary ZIP must be copied here separately.\n\nUse the **v3 package**, not the unsuccessful v1/v2 test modules. The v3 installer first performs a 30-second temporary verification and requires both physical button events and injected axes before allowing permanent installation. It does **not** automatically reboot.

> The original, tested v3 install bundle includes `NOVA-M1M2-TRIGGER-REPLACEMENT-MAGISK-v3.zip` (the Magisk-installable module), `nova_m1m2_native_v3.c`, the compiled ARM64 helper, the `.kl` layout, `service.sh`, `Install-Nova-M1M2-v3.ps1`, license, and integrity hashes. **Do not use a ZIP from an unofficial mirror.** The complete bundle's SHA-256 is `bcafff208e21af7b7a62d27381fc2da7edf1d87915a7af23bae74828b5c53776`; the inner Magisk module's SHA-256 is `f6302eb58537a7d5a4ba19c42bd28fbc8e1da047c994cf1fcf7bb03a8093ebb1`.

## Validation results

- Temporary native v3 test: M1=28, M2=26 physical button events, L2=28, R2=26 successful analog writes; 0 reported errors
- Magisk installation succeeded in slot `_a`; module registered as `nova_m1m2_triggers`
- After reboot: M1/M2 recognized as L2/R2 in GameNative and an independent controller tester
- OEM keypad test continues to label the physical M buttons, as expected

## Reversible rollback

Magisk → **Modules** → **Nova M1 M2 Physical Trigger Replacement** → **Disable** → Reboot. Alternatively uninstall the module in Magisk and reboot.

The boot service writes a log to `/data/adb/modules/nova_m1m2_triggers/bridge.log` for diagnostics.

## Notes for other Nova owners

- Do not assume codes 306/309 on a different firmware or a different Retroid handheld. Run `su -c 'getevent -lt'` and inspect the exact controller before modifying anything.
- A simple `.kl` edit alone does **not** synthesize analog trigger axes. That is why the native helper is necessary for games that expect analog L2/R2.
- Disable other remapping layers while diagnosing.
- This is a community-tested device-specific fix. Test and keep a rollback path before changing rooted input handling.

License: MIT (the helper source and bundled module). This directory is not an S108 fix.
