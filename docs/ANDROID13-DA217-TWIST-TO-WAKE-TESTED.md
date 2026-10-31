# S108 / W527 Android 13 — DA217 hardware twist-to-wake (tested prototype)

**Tested October 30, 2026:** XTQ S108, board `uws6152_1h10_go`, crDroid Android 13, built-in `mir3da` driver, DA217 sensor at I²C `2-0026`, IRQ 66, F10 input on `/dev/input/event5`.

**Status: proven temporary prototype; NOT a permanent battery-validated installation.** All device changes were restored at the end of the test. This is not a generic flashable package.

## Verified results

- DA217 tilt produces physical `KEY_F10` events via IRQ 66 with `irq1enable=1`.
- A temporary virtual input device with `key 68 F10 WAKE` delivered those events to Android. Android logged `WAKE_REASON_WAKE_KEY`, and the screen visibly woke on wrist movement.
- The original sensor INT1 latch setting was `0x21=0xCC` (25 ms). Testing `0x21=0xC9` (1 ms) preserved responsive physical twist-to-wake and greatly reduced IRQ bursts in the tested scenarios, although counts varied with motion.
- A 75-second stationary screen-off test with the 1 ms latch still woke when moved, showing two additional IRQs during the complete run.
- The subsequent three-cycle test succeeded **3/3**. IRQ 66 increments were 2, 4, and 13 for cycles 1–3 respectively. Each produced a real F10 relay event and Android's awake state. The first two wakes were followed by Android screen-off approximately five seconds later, with a ten-second re-arm cooldown.

## Tap-to-dismiss verified (October 30, V14)

Two independent two-cycle runs succeeded, **four physical wrist wakes total**. Each first cycle detected an actual `hyn_ts` touchscreen finger-down on `/dev/input/event8` and turned the screen off early; each second cycle recorded no tap and used the approximately five-second timeout. IRQ 66 increments per run were **5+7=12** and **3+2=5**, respectively. Watch-side logs reported `TAP_DISMISS_DETECTED` and `NO_TAP_FIVE_SECOND_TIMEOUT`, with final `irq1enable=0` and sensor latch restored to `0xCC`. These tests still showed the normal Android UI; **no dedicated white-on-black clock was verified yet**.

## V15 instability and cleanup warning (October 30)

An experimental two-cycle clock UI prototype failed **before** reaching its HTML clock launch: the physical DA217 relay received **no F10 event**, even though IRQ 66 increased by **284** in the first screen-off window. Earlier successful wake cycles did not justify enabling the sensor persistently.

**Safety-critical:** its Windows-side cleanup initially reported `irq1enable=1` despite watch-side cleanup having reported `0`. A subsequent **explicit rooted command and readback** confirmed `irq1enable=0`. The DA217 latch was verified restored to `0xCC`. Always verify the final IRQ sysfs value directly and treat failed disable writes as hard failures.

Clock rendering was **not evaluated** by this run. Subsequent UI trials should run without enabling the physical accelerometer interrupt.

## V16 clock UI rendering verified, separate from sensor

The October 30 V16 trial served a local HTML clock over `127.0.0.1` and Chrome returned HTTP 200. Two device screenshots independently confirmed a white-on-black clock displaying the correct local time. However, Chrome's address bar, Google account banner, Android status bar and navigation bar remained visible; the large 12-hour time including `PM` was cropped horizontally. V16 **did not touch the DA217 interrupt** and the final readback confirmed `irq1enable=0`.

A dedicated native fullscreen Android clock activity is preferable to browser kiosk workarounds. Any test APK should be installed temporarily, tested independently of IRQ 66, and removed afterward; no permanent wake service is yet validated.
## V17 native clock APK failure (October 30)

V17's first standalone clock APK installed successfully and `am start -W` returned `Status: ok`, but screenshots showed the Android home screen and a **"S108 Glance keeps stopping"** dialog. The actual AndroidRuntime log reported `ClassNotFoundException: com.s108.glance.ClockActivity`, with a nested DEX verifier error: **`String longer than indicated size 6`**. The offline DEX builder had erroneously written *two* ULEB128 length prefixes per `string_data_item`; Android requires only UTF-16 string length, then MUTF-8 data and terminator. Consequently V17 did **not** validate the native UI, timeout or tap handler. Cleanup successfully uninstalled the temporary APK, killed the leftover V16 server, and confirmed `irq1enable=0`.

A corrected V18 APK was built, signed, and passed independent offline DEX structural validation. **Its watch-side outcome is still pending**; do not mark the native clock as functional until it is verified on the device. V18 runs without enabling the DA217 interrupt.

## V18 ART verification failure, V19 candidate (October 30)

V18 corrected V17's invalid DEX string encoding and **installed successfully**, but it crashed before the activity could display. The Android 13 runtime reported `java.lang.VerifyError` in `ClockActivity.dispatchTouchEvent(MotionEvent)`: the generated code passed register `v1` (a `MotionEvent`) as the receiver for `Activity.finish()`; the correct receiver is `v0` (the Activity's `this`). V18 was uninstalled, with `irq1enable=0` verified.

V19 applies the precise register change and adds an independent DEX semantic check. The new check **rejects the actual V18 APK** and passes V19; ZIP structure and local test signature also verify. **V19 has not yet been tested on the S108**, so do not call the native clock operational until a real screenshot and activity lifecycle test pass. V19 leaves the DA217 interrupt off and uninstalls its test APK after the UI trials.

## V19 native fullscreen clock — verified (October 30)

V19 installed and ran successfully on the S108 with its physical DA217 interrupt **disabled**. The 480 × 480 screenshots show a large, centered white `9:59` native `TextClock` on a solid black, immersive fullscreen background, with no address bar, status bar or navigation buttons. The five-second timer and a touchscreen tap each closed the activity; the screenshots show the previous launcher afterward. Android's logs had **no ART VerifyError or application crash**. The test APK was uninstalled and `irq1enable=0` verified.

**Important behavior distinction:** `Activity.finish()` closes the clock but does not turn off the display. Returning to the home or previous app was expected for V19, not a regression in the gesture code. Android's `KEYCODE_SLEEP=223` is an explicit screen-sleep command and must be issued by an authorized controller, rather than assuming an unprivileged activity can call `PowerManager.goToSleep()`.

## V20 native clock dismissal -> display sleep — candidate, NOT yet device-tested

V20 adds a `S108Glance` tag on each actual native clock dismissal event (`DISMISS_TAP` or `DISMISS_TIMEOUT`). Its **temporary PC-side ADB controller** listens for those log events and sends Android `KEYCODE_SLEEP 223`, then verifies `dumpsys power` reports `mWakefulness=Asleep`. Two independent trials check timer and tap behavior, including launching Settings underneath the clock to distinguish screen sleep from returning to the previous screen. All results go to Windows Downloads; the temporary APK is uninstalled afterward; IRQ 66 is never activated. Its APK passed offline DEX structural and register tests and temporary-signature verification, **but on-watch validation is pending**. This event-driven host controller is an intermediate integration experiment, **not** a permanent battery-optimized service.

## V20 real display sleep — verified (October 30)

Both V20 native-clock dismissal tests passed on the S108 without activating the accelerometer interrupt. The five-second `DISMISS_TIMEOUT` and tapped `DISMISS_TAP` events triggered a temporary Windows-side ADB controller to send Android `KEYCODE_SLEEP=223`. Each resulting `dumpsys power` capture independently reported **`mWakefulness=Asleep`**, and logcat recorded `PowerManagerService: Going to sleep due to sleep_button`. The temporary APK was uninstalled and final `irq1enable=0` confirmed. V19 separately established the native clock's fullscreen visual appearance.

A V21 **candidate (not yet tested on-watch)** moves the dismissal-to-SLEEP controller from Windows onto the S108 itself using short-lived root-side logcat only while the clock is open. It filters events with a unique arming marker and a timeout guard; the Windows launcher provides two independent trials, verification and cleanup. V21 does not enable the unstable physical IRQ or install a boot-time service. This is an integration step, not proof of permanent low-power twist-to-wake.

## Critical unresolved issue

The vendor `mir3da` driver generated **19 `Unbalanced pm_runtime_enable!` warnings** during the three successful 1 ms cycles, matching the total IRQ count (2+4+13). The sensor's GPIO IRQ is level-triggered and the DA217 interrupt auto-latch is programmable, but the runtime-PM imbalance has **not** been corrected. These tests do **not** prove 24-hour standby efficiency, low false-wake rates, or safe permanent enablement.

Because the driver is built into the kernel, a true runtime-PM repair may require vendor kernel source reconstruction and careful per-device signing, rollback and boot verification. No kernel or firmware changes were made during these tests.

## Design that worked

1. Use the DA217's interrupt-driven tilt detection; **no continuous accelerometer polling**.
2. Temporarily set INT1 latch to 1 ms (sensor register `0x21=0xC9`) with chip-ID and current-register verification.
3. Set `irq1enable=1` only inside the bounded gesture window.
4. A blocking reader receives the genuine F10 input event, immediately disables `irq1enable`, and forwards F10 through a temporary uinput device mapped with `WAKE`.
5. Android wakes; the test issues a screen-off command approximately five seconds later and enforces a cooldown.
6. Cleanup restores `irq1enable=0` and `0x21=0xCC`, removes the temporary virtual keylayout, and verifies final state.

## Safety and distribution

The test was specific to one S108 running normal-boot Magisk 30.7 with powered-off charging. Preserve the known-good boot/recovery/AVB setup. Do not activate `irq1enable=1` at boot or install a permanent service on the assumption that the driver warnings are harmless. Any troubleshooting script should preflight the exact board, sensor ID, driver and register values, and have both watch-side and host-side rollback.

This write-up records the **verified result**; it does not contain signed images, firmware keys, private watch identifiers, or a permanent mod. The black-background clock glance and tap-to-dismiss remain separate implementation tasks.
