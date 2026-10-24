# W527 performance baseline — observations, not overclock instructions

Device: XTQ S108, Android 13 crDroid 9.3, kernel 4.14.98, board `uws6152_1h10_go`.

| Policy | CPU cores | Governor | Available frequencies (MHz) | Kernel min/max |
| --- | --- | --- | --- | --- |
| `policy0` | 0,1,2 | schedutil | 614.4,768,962,1144,1228.8,1482,1536,1716,1820 | 614.4 / 1820 |
| `policy3` | 3 | schedutil | 1228.8,1482,1536,1742,1820 | 1228.8 / 1820 |
| GPU devfreq `60000000.gpu` | IMG8300 | simple_ondemand | 384,512,614.4,768,800 | 384 / 800 |

Both schedutil `up_rate_limit_us` controls were already **500 µs**, so reducing CPU ramp-up latency via this parameter offered no practical target. `/dev/stune/top-app/schedtune.boost` read **15**, but writing even the original 15 failed with **Invalid argument**, so no boost increase was applied.

A single probe recorded `soc-thmzone=66984`, `board-thmzone=70055`, `gpu-thmzone=64646` (likely millidegrees Celsius). These are internal thermal-zone sensors, not external surface temperatures.

A +3°C modification of supported noncritical software trip points was **requested**, but no verified successful application is documented. Higher CPU/GPU **maxima were not unlocked**. Raising `scaling_max_freq` above listed kernel operating points cannot create new frequencies. Changing voltage/clock tables or thermal protections requires device-specific validation, and battery/critical shutdown cutoffs should not be raised casually.

User preference: improve tap/app responsiveness without maintaining permanently elevated minimum CPU/GPU clocks.
