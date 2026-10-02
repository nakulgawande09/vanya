# Vanya — Real-phone feel-test plan

> Part B of the Audio Bible / feel-test document (Part A is `docs/audio/audio-bible.md`). The
> sections below follow B1–B6. **How-to in this repo** sections say what is already built.

Goal: a 60-minute scripted session on one ₹10–15k Android (plus an iPhone XR/11 before launch).
Every red scorecard cell becomes a ticket with **one knob and one number** in
`client/data/feel/feel_tuning.tres` (for example "shake_god.x 8 → 6").

## B1. Device matrix

| Slot | What | Why | Source (estimate) |
|---|---|---|---|
| A-Low (must) | 3 GB Android 13–14, Helio G85/G88/G91 or Unisoc T606/T612, 720p/1080p, 60/90 Hz (Redmi 13C / A3 / A4, Narzo N, Galaxy M/A0x/F) | Low-tier budget target; Unisoc on Android 14 exposes thermal headroom | New ₹7–10k or refurbished ₹5–8k |
| A-Old (borrow) | Any 2 GB Android 11–12 (Go edition if possible) | Worst-case memory and audio latency | Family / friends |
| iOS (before launch) | iPhone XR / 11, iOS 17–18 | Haptics, notch, Ambient audio session | Refurbished ₹14–22k or borrow |

Also: cheap wired earbuds, a Bluetooth TWS pair (Bluetooth adds latency, so test both), and an IR thermometer (~₹800).

## B2. Fast deploy

| Platform | Once | Every build |
|---|---|---|
| Android USB | Developer options → USB debugging; Editor Settings → Export → Android SDK path; the "Android Debug" preset is Runnable; VIBRATE is enabled | `just deploy` (installs `out/android/vanya-debug.apk` and launches it), or the editor's one-click deploy |
| Android Wi-Fi | Wireless debugging → pair: `adb pair IP:PORT CODE`, then `just deploy-wifi IP:PORT` | Same; the remote debugger and profiler attach over Wi-Fi |
| iOS | Apple account, Team ID and bundle ID in the preset; first build through Xcode | One-click deploy, or Xcode Archive → TestFlight internal testers |

**How-to in this repo:**
- CI uploads a debug APK on every push (the `android-build` workflow artifact). Download it into `out/android/`, or build locally with `just export-android-debug`.
- `just logcat` tails Godot's log.
- `just pull-feeltest` copies every `feeltest_*.csv` off the phone into `out/feeltest/`. This works for debug builds only, via `run-as`.
- `just phone-stats` logs `dumpsys battery` and `dumpsys thermalservice` every 10 s from the computer. Use it as a cross-check for the in-game numbers.

## B3. Settings for feel testing

Already in `client/project.godot`: portrait, vsync on, `run/max_fps=60`, the Compatibility renderer, `physics_ticks_per_second=60` and physics interpolation.

`pointing/emulate_mouse_from_touch` stays **on**: turning it off would stop Godot buttons from responding to touch. The joystick reads touch events directly.

**Joystick:** `FloatingJoystick` has Fixed / Dynamic / Following modes, a dead zone, a clamp radius, a full-speed point and a response curve, all from `FeelTuning`. `joystick_builtin = true` swaps in Godot 4.7's own `VirtualJoystick` with the same mode, size and dead zone, so the two can be A/B tested on the phone.

**Debug overlay** (debug builds, or the `feeltest` feature tag): **3-finger tap** or **F3**.
- **Metrics**, refreshed once a second:
  - FPS, frame time avg / p95 / p99, jank (frames over 25 ms) per minute
  - process and physics ms, draw calls, static and video memory
  - audio voices / steals / drops, resident audio MB, reported output latency, current music clip
  - battery %, thermal headroom (`PowerManager.getThermalHeadroom` through JavaClassWrapper; -1 if unavailable)
  - quality rung
- **REC** writes those numbers to `user://feeltest_<date>.csv`, one row per second.
- **TUNE** has live sliders: stick mode, built-in stick on/off, dead zone, radius, full-speed point, curve, hit-stop ×, shake ×, haptics ×, aim retarget delay. **SAVE** writes `user://feel_tuning.tres`, which wins over the shipped tuning on the next launch. **RESET** deletes it.

## B4. 60-minute protocol

```
00–05  Setup: release-like build, 100% charge → unplug, brightness 75%, volume 60%, room temp,
       skin temp (back/centre), overlay on, REC on
05–15  INPUT (Room 1, Rotlings only): dead zone / sensitivity / mode A/B/C, thumb reach, one-handed
15–25  COMBAT FEEL: auto-aim, hit-stop scale 0.66 / 1.0 / 1.33, shake scale, flash, haptics Off/Low/Full
25–35  AUDIO: speaker vs wired vs BT; latency tap test; mix; music layering over build-up / peak
35–45  SUSTAINED: continuous play including Rotheart; at minute 20 record skin temp, headroom, p99, battery
45–55  INTERRUPTIONS: call, notification, headphones unplug, home/back, lock, ad revive, sunlight
55–60  Scorecard + 3 "worst moments"
```

**Scorecard** (score 1–5; a 2 or lower becomes a ticket):

| # | Test | How | Pass | Knob in `feel_tuning.tres` / code |
|---|---|---|---|---|
| 1 | Dead zone | micro-moves, precise stops | no drift; tiny moves possible | `joystick_deadzone` (0.10–0.25) |
| 2 | Sensitivity | full speed after ≤ 1 cm of thumb travel | full speed at 60–70% of the radius | `joystick_full_speed_at`, `joystick_curve`, `joystick_radius` |
| 3 | Stick mode | Fixed vs Dynamic vs Following, 2 min each | fewest "lost stick" moments | `joystick_mode`, `joystick_builtin` |
| 4 | Thumb reach | map comfortable areas | stick zone in the bottom 40%; nothing critical in the top 25% | HUD layout |
| 5 | One-handed | 3 min, each hand | survive Room 2 | joystick zone, `aim_range_scale` |
| 6 | Auto-aim | "did it shoot what you wanted?" per 20 shots | ≥ 17/20 | `aim_retarget_delay`, `aim_range_scale` |
| 7 | Hit-stop | scale 0.66 / 1 / 1.33 on kills, hurt, god, boss | crisp, never laggy | `hitstop_*`, `hitstop_scale`, `hitstop_min_gap` |
| 8 | Screen shake | per event | felt, no nausea, boss readable | `shake_*` (px, s), `shake_scale`; the settings toggle |
| 9 | Hit flash | 720p | readable | `flash_*` |
| 10 | Haptics | Off/Low/Full | distinct, not buzzy | `haptics[key]`, `haptic_scale`, `haptic_budget_per_s` |
| 11 | Frame pacing | 30-Rotling swarm + pan | p99 ≤ 20 ms at 60 fps; ≤ 1 jank/min | quality rungs, pools |
| 12 | Input latency | 240/120 fps slow-mo video | touch → motion ≤ 80 ms | process order |
| 13 | Audio latency | second phone records tap + bow sound | ≤ 100 ms on speaker (log BT separately) | WAV SFX; earlier trigger |
| 14 | Speaker vs earbuds | same boss fight | hurt / telegraph always audible | BOM levels, ducking (`duck_db`) |
| 15 | Music layering | overlay `music_clip` + listening | bar-locked, no clicks, no pumping | `StemMixer` fades, hysteresis |
| 16 | Thermal | skin temperature and headroom at 20 min | ≤ 40 °C; headroom < 0.8; p99 stable | `max_fps`, quality rungs |
| 17 | Battery | % per 10 min | ≤ 3–4% on A-Low | fps cap, darkness cost |
| 18 | Sunlight | outdoors, noon | enemies, projectiles and pickups distinguishable | palette, outlines |
| 19 | Notch / safe area | punch-hole Android, iPhone notch | no HUD under the notch or gesture bar | `SafeArea` (already applied to the HUD and camp) |
| 20 | Back | back gesture mid-fight and at camp | pauses in a run; at camp, two presses to exit | `NOTIFICATION_WM_GO_BACK_REQUEST` (done) |
| 21 | Interruptions | call, notification, unplug, BT drop, lock, app switch, rewarded ad | pauses; nothing blasts after an unplug; resumes paused with a fade-in; ad audio never mixes with the game | `GodotAudio` lifecycle (done); Android focus/noisy needs a plugin if this fails |
| 22 | iOS silent switch / user music | Spotify → game; silent switch | user music continues; game obeys the switch | iOS session (later) |

**Starting values** (shipped in `FeelTuning`):

| Event | Hit-stop | Shake (px, s) | Haptic (ms, amp) |
|---|---|---|---|
| Normal arrow hit | 0 | 0 | none |
| Crit (no crits yet) | 45 ms | 2, 0.08 | 20, 0.4 |
| Rotling kill | 30 ms (at most one stop per 100 ms) | 1.5, 0.06 | none |
| Thornback kill | 70 ms | 5, 0.2 | 60, 0.9 |
| Player hurt | 60 ms | 4, 0.15 + red vignette | 40, 0.7 |
| God impact | 80 ms | 8, 0.3 + flash | 80, 1.0 |
| Boss wall hit / stun | 90 ms | 10, 0.35 | 60, 0.9 |

## B5. Android audio latency in 4.7

- Godot 4.7 on Android still uses OpenSL ES. `audio/driver/output_latency` is ignored on Android. Expect about 100–250 ms on cheap phones.
- Mitigations already in place:
  - feedback is visual and haptic first
  - short SFX are WAV, imported as QOA, so there is little to decode
  - generated sounds have no leading silence
  - gameplay never syncs to the audio clock
- Still to try if the tap test fails: trigger the bow sound on aim-lock instead of on release. If p50 is still over 150 ms on A-Low, try a custom template with the OpenSL fast-track patch.
- The overlay shows `AudioServer.get_output_latency()`, which Android may report as 0. Measure with a second phone's microphone.

## B6. Results

Copy `docs/feel-test/results-template.md` to `docs/feel-test/results/<date>-<device>.md`. Paste in the metrics block that `python3 tools/feeltest_report.py out/feeltest/<file>.csv` prints. Turn each red row into a ticket with one knob and one number. Re-run only the rows affected on the next build.

## Caveats

- Live stem volume changes were verified headless: muting all stems through `set_sync_stream_volume` dropped the mixed output by about 60 dB. Clicks have to be checked on a device.
- Battery and thermal readings use Android APIs through JavaClassWrapper. They are untested on hardware in this repo; `just phone-stats` is the fallback.
- Loudness targets are guidelines, not certification. Re-check them on the phone speaker, not studio monitors.
