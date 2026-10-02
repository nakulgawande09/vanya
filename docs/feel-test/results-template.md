# FEELTEST #__

- Date: ____
- Build: ____ (git sha)
- Device: ____
- OS: ____
- Tester: ____
- Ambient: room __ °C, start battery __%, brightness __%
- Tuning: shipped / `user://feel_tuning.tres` (attach it if overridden)

| # | Test | Score 1–5 | Measured value | Observation (what felt wrong) | Change (knob: old → new) | Owner | Re-test |
|---|---|---|---|---|---|---|---|
| 1 | Dead zone | | | | `joystick_deadzone` 0.12 → | | |
| 2 | Sensitivity | | | | `joystick_full_speed_at` 0.65 → | | |
| 3 | Stick mode | | | | `joystick_mode` DYNAMIC → | | |
| 4 | Thumb reach | | | | | | |
| 5 | One-handed | | | | | | |
| 6 | Auto-aim | | __/20 | | `aim_retarget_delay` 0.0 → | | |
| 7 | Hit-stop | | | | `hitstop_*` | | |
| 8 | Screen shake | | | | `shake_*` | | |
| 9 | Hit flash | | | | `flash_*` | | |
| 10 | Haptics | | | | `haptics[...]` | | |
| 11 | Frame pacing | | p99 __ ms, jank __/min | | | | |
| 12 | Input latency | | __ ms | | | | |
| 13 | Audio latency | | __ ms speaker / __ ms BT | | | | |
| 14 | Speaker vs earbuds | | | | | | |
| 15 | Music layering | | | | | | |
| 16 | Thermal | | __ °C, headroom __ | | | | |
| 17 | Battery | | __%/10 min | | | | |
| 18 | Sunlight | | | | | | |
| 19 | Notch / safe area | | | | | | |
| 20 | Back | | | | | | |
| 21 | Interruptions | | | | | | |
| 22 | iOS silent / user music | | | | | | |

**Metrics summary.** Paste the output of `python3 tools/feeltest_report.py out/feeltest/<file>.csv`:

```
```

**Top 3 worst moments** (timestamp + description):
1. ___
2. ___
3. ___

**Decision:** ☐ ship to next playtest ☐ re-test after changes ☐ blocker
