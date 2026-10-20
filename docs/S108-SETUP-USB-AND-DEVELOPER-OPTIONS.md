# XTQ S108 W527: APK installation, USB ADB, full Developer Options, and USB tethering

**Tested device:** XTQ S108, Unisoc W527/UWS6152, stock Android 9 (API 28), firmware `DW_W527_FW13FBA_V35_XTQ_S108_J0_GB_CN_ZX_W4.0T_4.4V_256X24B_CN_480X480_V01_20260914_2050`.

**What was actually confirmed:** ADB connected over USB as `device`, the full developer menu opened, the standard menu activity was enabled, and the fix survived a normal reboot. USB tethering's **toggle** was accessible and was turned on, but a functioning tethered **network connection** on Windows has **not been proven**. These are two different USB features.

> **Safety:** These instructions do not require Magisk, root, reflashing, IMEI changes, or modem/NV writes. Do not use the helper app's identity-spoofing, IMEI, band-write or modem-reset functions to complete this guide.

## 1. Get the APK onto the watch using its browser

A separate file manager is not required to install an APK.

1. Connect the **watch** to Wi-Fi and open its built-in web browser (or install/open a browser already available on the watch).
2. Visit the original AILIFE developer project: **https://gitlab.com/ailife8881/dw-smartwatch-developer-helper**. Find the APK `smartwatch_devoption.apk` (the project's Releases page or repository files, depending on what GitLab displays). The app is called **Developer Helper for DW by AILIFE V5.0** on the tested S108. The upstream project lists support for some other XTQ W527 watches; compatibility with this S108 was confirmed experimentally.
3. Tap the APK download in the browser. When the download completes, **open the browser's menu → Downloads** (or tap the download-complete notification). **Tap the downloaded APK** to open Android's package installer. The Downloads page is a practical replacement for navigating to the APK with a separate file manager.
4. If Android says **Install unknown apps** is blocked, open the offered Settings screen and **Allow from this source** for that browser. Return to the downloaded file and tap Install. On some firmware, this is labeled **Unknown sources** rather than a per-app permission.
5. Launch **Developer Helper for DW by AILIFE**. Do not use its **change IMEI / model / fake specifications** features.

For other APKs (such as **Activity Launcher** or a file manager), repeat the same process using their respective trusted upstream sources. Don't install modified APKs from random mirrors. A browser's **Downloads** menu also gives you access to files you downloaded even when the watch's launcher doesn't expose a file manager.

**If GitLab is difficult to navigate on the watch:** copy the complete download link from a phone/PC and type it in the watch browser; avoid relying on an invented mirror URL. You can use [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools) to install APKs later, *after* ADB is working, with `adb install -r <path-to-file.apk>`.

## 2. Access the watch's Engineering Mode / on-watch ADB Shell

On the tested unit, the helper's **UNISOC test mode** button opened **EngineerMode**, including a TELEPHONY tab. The OEM **Engineering Mode → ADB Shell** field is the critical interface for the commands below.

1. Open the AILIFE helper and tap **UNISOC test mode**.
2. Find the OEM **Engineering Mode** / **ADB Shell** screen. Depending on the firmware this can be in a separate Engineering Mode application or within its test interface.
3. Paste **one command at a time** in the watch-side **ADB Shell**, press its execute/end button, and wait for the screen to react. On the tested firmware this interface executes with Android UID **1000 (system)**; ordinary Termux or the PC's ADB shell does **not** have equivalent privileges.
4. The app may leave its **Command result** blank even when the command succeeds. Check the resulting screen or verify through PC ADB rather than assuming a blank result is failure.

If your keyboard makes pasting difficult, transfer the [plain text command files](../commands/) through your preferred watch transfer method; copy/paste their contents without Markdown formatting. Once USB debugging works, **scrcpy** can mirror the watch and make copying/pasting much easier.

## 3. Enable USB debugging / ADB with the hidden OEM switch

In **Engineering Mode → ADB Shell** on the **watch**, run **[command 01](../commands/01-Open-OEM-ADB-Settings.txt)**:

```sh
am start --user 0 -n com.android.settings/com.android.settings.DwDevelopmentSettingsActivity --ei debug_type 1
```

The OEM Developer Settings screen should appear. Switch **Enable ADB** (may be labeled **USB debugging**) **ON**.

**Why this works:** The extracted stock S108 `Settings.apk` contains an OEM activity `DwDevelopmentSettingsActivity` with an `enable_adb` preference; it displays that preference with the `debug_type=1` extra. The firmware also contains USB gadget and `adbd` initialization definitions. This avoids the normal Developer Options activity, which was explicitly disabled.

### Connect to the PC

1. Use a USB **data-capable** cable / the working S108 USB connection.
2. On Windows, install Google's [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools), open PowerShell in the platform-tools folder, and run:

   ```powershell
   .\adb devices
   ```

3. Approve the RSA **Allow USB debugging?** prompt on the watch if asked. The device should appear as `device` (the example unit showed `89048037910009  device`; **your serial will be different**).
4. If `unauthorized`, unlock the watch and approve the prompt. If the list is empty, check USB cable, contacts, drivers and the OEM **Enable ADB** switch. Don't confuse a charging-only cable with a data cable.

> **USB debugging is not USB tethering.** ADB simply gives the PC a debugging connection.

## 4. Enable the full Developer Options menu

On the **PC**, with authorized ADB, tell Android that the user is a developer:

```powershell
.\adb shell settings put global development_settings_enabled 1
```

This is persistent, but **not sufficient on its own**. The stock S108 `com.android.settings` package had this full-menu activity in its **disabledComponents** list:

`com.android.settings.Settings$DevelopmentSettingsDashboardActivity`

From the **watch's privileged Engineering Mode → ADB Shell**, run [command 03](../commands/03-Enable-Standard-Developer-Options.txt):

```sh
pm enable --user 0 'com.android.settings/.Settings$DevelopmentSettingsDashboardActivity'
```

**Use single quotes** around the component so the `$` is not expanded as a shell variable. This command succeeded on the tested device.

**Do not run this `pm enable` command from the ordinary Windows/PC ADB shell.** It was tested there and rejected:

```text
java.lang.SecurityException: Shell cannot change component state
```

The watch's ADB Shell is named similarly but executes with different permissions.

### Open the menu

Once the component has been enabled, the PC can launch the ordinary Developer Options screen:

```powershell
.\adb shell am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS
```

**Fallback if the normal component remains disabled:** use [command 02](../commands/02-Open-Full-Developer-Options.txt) **inside the watch's Engineering Mode ADB Shell**:

```sh
am start --user 0 -n com.android.settings/.SubSettings --es :settings:show_fragment com.android.settings.development.DevelopmentSettingsDashboardFragment
```

That fallback successfully opened the *full* Developer Options UI before the default activity was re-enabled. Running it directly from **PC ADB** was rejected (`not exported from uid 1000`), which is expected; launch it with the watch's system-UID Engineering Mode shell.

**Verification from PC:**

```powershell
.\adb shell settings get global development_settings_enabled
.\adb shell dumpsys package com.android.settings
```

The setting should be `1`. Look under user 0: `Settings$DevelopmentSettingsDashboardActivity` should appear under `enabledComponents`, not `disabledComponents`. Once we achieved this, ordinary `am start` opened the full menu.

### Make it accessible on the watch without Engineering Mode

Install **Activity Launcher** (with the browser + Downloads APK workflow from step 1, if needed). Search for **Settings** / `com.android.settings` and select:

`Settings$DevelopmentSettingsDashboardActivity`

Test that it opens, then **favorite** it in Activity Launcher. A normal launcher shortcut may not be supported on the S108; favoriting is confirmed working.

The OEM/custom Settings app **may still omit a visible Developer Options menu row**. Activity Launcher provides easy access without modifying the OEM Settings UI.

### Restart / persistence

On the tested S108, the enabled activity, developer status, and access to Developer Options **survived a normal reboot**. A factory reset or firmware update may reset these changes. If ADB stops connecting, revisit the OEM **Enable ADB** switch from step 3; don't turn off the master Developer Options switch by accident.

## 5. USB network tethering (separate feature; connection still unverified)

The original troubleshooting succeeded in **turning on the watch's USB Network Tethering toggle**. It did **not** establish a working USB network connection with the Windows PC. These are **different success criteria**.

To find Android's tethering settings, run [command 04](../commands/04-Open-USB-Tether-Settings.txt) from an appropriate shell (PC ADB after authorization, or watch-side Engineering Mode if necessary):

```sh
am start -a android.settings.TETHER_SETTINGS
```

On the watch, look for **Hotspot & tethering** / **USB tethering** / **USB Network Tethering** and switch it ON. The command above **only opens Settings**; it does **not** force tethering on.

If the watch's normal Settings hides the switch, AILIFE's helper may expose USB-related modes on some firmware versions, but there is no verified general-purpose shell command here for bypassing a disabled tethering toggle. Treat any helper mode-switch as firmware-dependent.

**Test before calling it a working tethering connection:**

1. Make sure the watch actually has an internet uplink (Wi-Fi or mobile data); a watch with no cellular registration cannot supply cellular internet just by toggling tethering.
2. Connect the watch to Windows with a data-capable cable, and toggle **USB Network Tethering** on.
3. On Windows, inspect **Network Connections / Device Manager** for a new **Remote NDIS Compatible Device**, RNDIS, or USB Ethernet interface. Check that it receives an IP address and has connectivity.
4. Record whether switching on tethering replaces the USB debugging interface; if it does, this is a USB function-switching issue and **not** an ADB failure.
5. If Windows does not enumerate a network adapter, note the behavior as **toggle on / no confirmed RNDIS interface** and do not call USB networking fixed.

**Do not** set `sys.usb.config`, `persist.sys.usb.config`, USB gadget nodes, or modem-NV values blindly. Such changes can disconnect ADB, and the watch needs a tested way back in before experimentation.

## 6. Troubleshooting

| Symptom | Explanation / safe next step |
| --- | --- |
| Tapping Build Number says “Already a developer” but no menu shows | `development_settings_enabled=1` is distinct from the component's enabled state; run step 4. |
| Normal Developer Options intent opens a disabled page or returns Error type 3 | The default dashboard may still be disabled; run command 03 **in Engineering Mode ADB Shell**. |
| `pm enable` returns `SecurityException` | You ran it as normal `uid=2000(shell)`, or the privileged helper lacks permission on your build. Verify you're in the **watch's** system-UID Engineering Mode shell. |
| PC `am start` to `com.android.settings/.SubSettings` returns “not exported” | Expected: it is a non-exported Settings activity. Use command 02 in the privileged Engineering Mode shell. |
| Watch-side ADB Shell shows blank command result | That happened on the tested unit even when the `pm enable` command succeeded. Verify with `dumpsys package com.android.settings`. |
| `adb devices` shows `unauthorized` | Approve the USB authorization prompt on the watch. |
| Standard Developer Options accessible, but absent from Settings menu | Favorite the specific activity in Activity Launcher; it worked after reboot. |
| Browser installs fail | Browser → Downloads → APK → allow installs from browser as needed. |
| USB tether toggle turns on but Windows has no network | **Unresolved.** Collect Windows adapter/device details and Android USB state before modifying USB configs. |

### Optional Windows read-only verification

From PowerShell run [Verify-S108-ADB.ps1](../scripts/Verify-S108-ADB.ps1) after downloading it. It asks you to verify the serial before running and checks Android version, ADB state, developer flags and the enabled/disabled Settings activity; it makes no changes.

## Credits / sources

- **AILIFE:** [DW smartwatch developer helper](https://gitlab.com/ailife8881/dw-smartwatch-developer-helper), source for the third-party helper APK; not redistributed here.
- **Google:** [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools).
- Discovery of OEM Settings activity, `debug_type=1`, system UID activation, and reboot persistence: directly tested on the XTQ S108 stock firmware described above.

This is a **community-device guide**, not a generic W527 flashing procedure. Never use S100-specific firmware or loaders to write S108 partitions.
