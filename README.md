# S108 W527 Full Android Watch — Fixes & Setup

Community notes for the **XTQ S108 / S108 W527 full-Android smartwatch**, tested on stock **Android 9 (API 28)**. The S108 is **not** the S100; do not flash S100 images or assume its firmware matches.

## Confirmed working on an S108

- **Enable wired USB ADB** using the OEM's hidden `Enable ADB` switch in Engineering Mode.
- **Unlock and launch the full Android Developer Options screen** despite the default activity being disabled.
- **Make Developer Options launchable through standard ADB / Activity Launcher.**
- **Persist after a normal reboot:** developer status, activity enablement, and access to the full menu were confirmed.
- **Install APKs without a separate file manager** using the browser's **Downloads** screen.

**USB tethering is separate from USB debugging.** The **USB Network Tethering** toggle could be switched on, but a working RNDIS/network connection on the Windows PC was **not** verified. Do not interpret successful ADB connection as proof of tethered internet.

## Start here

**[Full illustrated-by-commands walkthrough: Browser downloads → AILIFE APK → Engineering Mode → ADB → Developer Options → USB tethering](docs/S108-SETUP-USB-AND-DEVELOPER-OPTIONS.md)**

The guide covers the entire path from a stock watch with no PC-side ADB to the tested result, plus troubleshooting and safe verification.

### Downloads and commands

| Resource | Purpose |
| --- | --- |
| [AILIFE DW smartwatch developer helper — original developer project](https://gitlab.com/ailife8881/dw-smartwatch-developer-helper) | Download **Developer Helper for DW by AILIFE V5.0** (`smartwatch_devoption.apk`). Use the upstream copy. |
| [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools) | Obtain `adb` on Windows/macOS/Linux. |
| [01 — Open OEM USB debugging](commands/01-Open-OEM-ADB-Settings.txt) | Paste in **Engineering Mode → ADB Shell**, not in PowerShell. |
| [02 — Open full Developer Options](commands/02-Open-Full-Developer-Options.txt) | Paste in **Engineering Mode → ADB Shell**. |
| [03 — Enable standard Developer Options activity](commands/03-Enable-Standard-Developer-Options.txt) | Paste in **Engineering Mode → ADB Shell**; requires its privileged UID. |
| [04 — Open USB tether settings](commands/04-Open-USB-Tether-Settings.txt) | Opens Settings; **does not itself enable tethering**. |
| [Windows ADB verification script](scripts/Verify-S108-ADB.ps1) | Read-only verification once ADB is working. |

## Five-minute route (once the helper is installed)

1. Open **Developer Helper for DW by AILIFE V5.0**. Tap **UNISOC test mode** to reach EngineerMode if supported by your firmware.
2. Go to the watch's **Engineering Mode → ADB Shell** (the *on-watch* shell that ran as `uid=1000(system)` on the tested device).
3. Launch the OEM's hidden USB-debugging menu:

   ~~~sh
   am start --user 0 -n com.android.settings/com.android.settings.DwDevelopmentSettingsActivity --ei debug_type 1
   ~~~

4. Switch **Enable ADB / USB debugging** on; attach a **USB data-capable** cable and authorize the computer if prompted. Run `adb devices` on your PC; it should say `device`, not `unauthorized`.
5. To expose the full menu, in the **on-watch Engineering Mode ADB Shell** run:

   ~~~sh
   pm enable --user 0 'com.android.settings/.Settings$DevelopmentSettingsDashboardActivity'
   ~~~

   On a PC with authorized ADB, enable developer status if necessary: `adb shell settings put global development_settings_enabled 1`.
6. Open the standard menu from the PC: `adb shell am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS`. If it does not open, use [the OEM full-menu fragment command](commands/02-Open-Full-Developer-Options.txt) from Engineering Mode.
7. Use **Activity Launcher** to find and **favorite** `Settings$DevelopmentSettingsDashboardActivity`. Some S108 launchers do not support creating a home-screen shortcut.

**Important:** `adb shell pm enable` from the ordinary PC ADB shell can fail with a `SecurityException`. The tested fix was to run `pm enable` from the privileged **Engineering Mode ADB Shell**, *not* ordinary ADB or Termux.

## Tested scope and cautions

- Device: XTQ-S108, Unisoc W527 / UWS6152 family, OEM Android 9. Tested firmware identifier: `DW_W527_FW13FBA_V35_XTQ_S108_J0_GB_CN_ZX_W4.0T_4.4V_256X24B_CN_480X480_V01_20260914_2050`.
- No root, bootloader unlock, firmware flashing, IMEI change, or modem/NV edit was needed for the Developer Options fix.
- The OEM's modified Settings menu may **not display** Developer Options as an ordinary menu item even after the activity is enabled; launching it and favoriting it in Activity Launcher works.
- Results are from one real S108; other W527 watch variants and firmware builds can differ.
- Third-party APKs remain their developers' work. We link to the **AILIFE original project** rather than bundling its APK in this repository.
- Be cautious in EngineerMode: **do not touch IMEI changes, modem NV writes, BandSelect Save/Reset, or untested USB functions** while following this guide.

## Status

| Feature | Tested outcome |
| --- | --- |
| Hidden OEM ADB control | Working |
| Authorized wired `adb devices` | Working |
| Full Developer Options | Working |
| Normal Developer Options activity enabled | Working |
| Developer Options access after reboot | Working |
| Activity Launcher favorite | Working |
| Windows USB/RNDIS tethering data connection | **Unverified** |
| Root / Android 13 crDroid on S108 | **Not implemented** |

Issues and contributions are welcome; include your **exact watch model, firmware version, Android version, and what step failed**, but redact IMEI, SIM, IMSI, ICCID, phone numbers, and personal identifiers.
