# S108 Android 13 side-button remapping (confirmed working)

**Platform:** XTQ S108 / Unisoc W527, crDroid 9.3 Android 13, Magisk. This is not the stock-Android-9 developer-options procedure.

This mapping **was verified on a physical S108 and survived a reboot**:

| Button | Single | Hold | Double |
| --- | --- | --- | --- |
| Left (KEY_F9) | Back (after 460 ms to rule out double) | Volume up one notch, showing slider | Toggle 0° ↔ 90° orientation |
| Right (KEY_POWER) | Stock screen on/off | Stock power menu | Wake + Home instead of camera |

The buttons were observed on `gpio-keys` (/dev/input/event7 during the test), but event numbers can change. The module resolves `gpio-keys` by device name; it does not change any `.kl` key layout or grab the input device. The extra KEY_F2 event on `madev` was not the side-button pair.

**Source files:** [Magisk module source](../modules/s108_button_mapper/). The module stores original camera and rotation settings for rollback. It disables Android's camera double-press shortcut and injects Home on a double KEY_POWER; the default power presses remain handled by Android.

**Important FIFO/Binder workaround:** Initial live tests detected the correct gestures but failed with `Failure calling service input: Failed transaction (2147483646)`. The event listener reads from a FIFO; Android service commands must not inherit the FIFO as stdin (or inappropriate log descriptors). The verified implementation launches `input`, `wm`, and `settings` operations using `</dev/null >/dev/null 2>&1`.

**Installing:** This repository contains transparent source rather than a firmware image. Copy the `modules/s108_button_mapper` folder into a fresh Magisk module directory `/data/adb/modules/s108_button_mapper` from a root shell, set executable permissions for `service.sh`, `button_daemon.sh`, `stop.sh`, and `uninstall.sh`, create an empty `skip_mount` file, then reboot. Back up anything at that path first; do not overwrite an existing module blindly. You may instead use the tested installer distributed with the session handoff, but its ADB paths/device connection may need updating.

**Safe rollback:** Create `/data/adb/modules/s108_button_mapper/disable` and run `sh /data/adb/modules/s108_button_mapper/stop.sh` as root. If input handling becomes unusable, use ADB recovery to disable the module. The status bar, navbar, and LTE modules are independent.

**Caveats:** Volume hold increases volume *one step* and shows the slider; it is not a continuous-volume adjustment. Rotation is a manual 0°/90° toggle. Triple-taps and very rapid input may not match the tested timings. Avoid replacing `KEY_POWER` because long-hold power-menu access is intentionally preserved.
