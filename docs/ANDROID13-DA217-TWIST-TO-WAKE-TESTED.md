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
