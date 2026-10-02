# Vanya — Audio Bible (spec)

> Source: "Vanya: Guardians of the Grove — Audio Bible, Implementation Plan & Real-Phone Feel-Test Plan".
> Part A (this file) is the audio spec; Part B lives in `docs/feel-test/feel-test-plan.md`.
> How the repo implements it, and where it deviates, is in ADR-0007 and the "Implementation" notes at the end.

**Bottom line:** Ship placeholder audio this week through one audio system that looks up sounds by archetype ID, and put adaptive music on Godot's built-in `AudioStreamInteractive` + `AudioStreamSynchronized`. Mix to about −18 LUFS / −1 dBTP. Then test feel on a ₹10–15k Android phone. On Godot 4.7.x Android still uses OpenSL ES and `output_latency` is ignored there, so measure audio latency on the device rather than trying to tune it.

## A1. Direction — "The Sound of Vanya"

**Tone words:** hushed · woody · breathing · ritual-rhythmic · glowing · rotting-wrong · heroic-earthy.

| World | Character | Palette | Timbre rules |
|---|---|---|---|
| Grove (nature, safe) | Organic, dry-to-airy, mid-centred, human-made | Crickets, owls, frogs, bamboo wind, stream; tarpa-style double-flute drones, bansuri breath, dholki/dhol skins, ghungroo, wooden clappers, low hums | Real(-sounding), tuned to the home key, no detune |
| Spirit (gods, rescues, spirit currency) | Glassy, shimmering, high, consonant | Glass bells, bowed glass/singing bowl, breathy flute, harmonic chimes | Always consonant, pentatonic, rising pitch = reward |
| Blight (enemies, portals, gate seal) | Wrong, unstable, low and pulsing | Detuned/reversed grove sounds, granular smears, 40–60 Hz sub pulses, wet squelch, violet "fizz" | Detune ±30–70 cents, reversed attacks, tritones, no clean pitch |
| Gods (battle) | Big, short, hybrid organic hits | Dhak/dhol + thunder (Meghra); stone crack + bull snort + sub (Dhoru); vine creak + wooden rattle + chime (Vayli) | Transient-first, short tails |

**Leitmotif:** a pentatonic spirit motif D–E–G–A–(D′): breathy flute in camp, glass bells on rescues and spirit pickups, detuned and slowed for Rotheart's heart. When the boss dies the motif returns un-detuned — the audio payoff of "un-blighting".

**Phone mix philosophy**
- Phone speakers roll off below ~200–300 Hz: every low-end event needs a mid "ghost" layer (click/crack/snap at 1–4 kHz). Sub is a bonus for earbuds.
- Always-heard hierarchy: player hurt > boss telegraph > god impact > player arrow hit > pickups > enemies > music > ambience.
- Voice caps per archetype are mandatory (A2) so Rotling swarms don't sum into noise.
- Music sits under the game: duck −4…−6 dB on big events; drop the melody stem when a boss telegraph plays.

**Loudness targets**

| Item | Target |
|---|---|
| Whole game (30-min capture) | −18 LUFS ±2 (aim −17); Sony ASWG-R001 portable target −18 ±2 LKFS |
| True peak | ≤ −1 dBTP (master limiter −1.0) |
| Loudness range | 10–15 LU |
| Music stems (each, solo) | −23 to −20 LUFS-I |
| SFX momentary loudness | loudest (god impact, boss slam) ≈ −13; loud (hurt, gate) −18…−14; focus (arrow hit, pickups) −23…−18; average (steps, enemy idle) ≈ −23; quiet (ambience details) ≈ −28 |

Ads (AdMob rewarded) are much louder than games: duck/pause all game buses while an ad plays, fade back over 500 ms.

**Frequency allocation**

```
Hz:   20   60   120   250    500    1k     2k     4k     8k    16k
SUB   [Blight pulse, Rotheart heart, god sub-thumps]  ← earbuds only; ALWAYS add a mid layer
LOW        [dhol/dhak body, Thornback stomp, charge rumble]  ← music bass stem cut −3 dB here
LOW-MID          [music drone/bed, tarpa drone, Rotling grunts]  ← mud zone: HPF ambience at 150 Hz
MID                     [MELODY (flute/tarpa), hurt vocal, Wisp body]  ← melody owns 500–2k
HIGH-MID                              [arrow release/impact click, UI, pickups, ghungroo]  ← speaker sweet spot
HIGH                                          [crickets, spirit bells, shimmer, Jugnu]  ← LPF ambience at 10k on low tier
```

Rules: HPF all ambience at 150 Hz; HPF all SFX (except sub-designed) at 80 Hz; static −2 dB around 2.5 kHz on the music bus so arrow transients cut through.

**Cultural respect**

| Do | Don't |
|---|---|
| Credit as "inspired by Warli/Adivasi traditions of the Sahyadri region" | Claim "authentic Warli music" |
| Hire a Maharashtra-based tarpa/dhol musician, ideally a community artist; pay and credit by name | Sample ritual field recordings (weddings, Tarpa dance festivals, funerary/worship music) |
| Use instrument timbres and rhythmic feel; compose original melodies | Reproduce identifiable traditional songs/chants; use sacred-sounding vocals for blight |
| Use generic hums/vowels ("aa", "hm") | Invent "tribal words" imitating a real language |

## A2. SFX bill of materials

Tier = ducking/steal priority (P0 never stolen → P4 stolen first). Poly = max simultaneous. Pos: N non-positional, Pan = gentle pan by screen X. ID convention `sfx.<domain>.<entity>.<action>[.<variant>]`; files `sfx_<domain>_<entity>_<action>_<var>_<nn>`. The machine-readable BOM (variants, tier, poly, loop, pos, cooldown, haptic, synth recipe) is `pipelines/audio/bom.json`; this table is its source.

### Player
| ID | Trigger | Var | Tier | Dur | Poly | Loop | Pos |
|---|---|---|---|---|---|---|---|
| sfx.player.step.{earth,grass,water} | footstep frame | 6 each | P4 | 80–150 ms | 2 | N | N |
| sfx.player.bow.draw | aim acquires target / wind-up | 3 | P3 | 150–250 ms | 1 | N | N |
| sfx.player.bow.release.{t1..t4} | arrow fired; higher tier = more body + shimmer | 4/tier | P2 | 100–200 ms | 3 | N | Pan |
| sfx.player.arrow.impact.{flesh,bark,stone,armor} | arrow hit by material | 4 each | P2 | 80–200 ms | 4 | N | Pan |
| sfx.player.hurt | damaged | 4 | P0 | 200–350 ms | 1 | N | N |
| sfx.player.death | HP 0 | 1 | P0 | 1.5–2.5 s | 1 | N | N |
| sfx.player.revive | rewarded revive | 1 | P0 | 1.5 s | 1 | N | N |
| sfx.player.tier_up | level/arrow tier up | 2 | P1 | 1.0 s | 1 | N | N |

### Enemies and boss
| ID | Trigger | Var | Tier | Dur | Poly | Loop | Pos |
|---|---|---|---|---|---|---|---|
| sfx.enemy.rotling.idle / .alert | random 4–9 s (2 nearest only) / aggro | 3/3 | P4/P3 | 300–600 ms | 2 | N | Pan |
| sfx.enemy.rotling.attack | lunge | 3 | P3 | 200 ms | 3 | N | Pan |
| sfx.enemy.rotling.hurt | non-lethal hit | 3 | P3 | 150 ms | 3 | N | Pan |
| sfx.enemy.rotling.death | kill (squeal → reversed fizz) | 3 | P2 | 300–500 ms | 3 | N | Pan |
| sfx.enemy.thornback.stomp | walk cycle | 3 | P3 | 200 ms | 1 | N | Pan |
| sfx.enemy.thornback.windup | telegraph (must read) | 2 | P1 | 500–800 ms | 1 | N | Pan |
| sfx.enemy.thornback.slam | ground slam | 2 | P1 | 600 ms | 1 | N | Pan |
| sfx.enemy.thornback.armor_hit | deflect "tink-thunk" | 4 | P2 | 120 ms | 2 | N | Pan |
| sfx.enemy.thornback.death | kill | 2 | P1 | 1.0 s | 1 | N | Pan |
| sfx.enemy.wisp.float_loop | while alive | 1 | P4 | 2–4 s | 2 | Y | Pan |
| sfx.enemy.wisp.spit | fires orb | 3 | P2 | 200 ms | 3 | N | Pan |
| sfx.enemy.wisp.orb_impact | orb hits | 2 | P2 | 200 ms | 3 | N | Pan |
| sfx.enemy.wisp.hurt / .death | hit / kill (reverse glass shatter) | 3/2 | P3/P2 | 150/600 ms | 2 | N | Pan |
| sfx.boss.rotheart.heart_loop | whole fight; rate follows phase | 1 | P1 | 1 beat | 1 | Y | N |
| sfx.boss.rotheart.stalk | stalk breath/snort | 3 | P2 | 0.5–1 s | 1 | N | Pan |
| sfx.boss.rotheart.telegraph | charge warning, ends at charge start | 1 | P0 | 0.8–1.2 s | 1 | N | N |
| sfx.boss.rotheart.charge_loop | charge | 1 | P1 | loop | 1 | Y | Pan |
| sfx.boss.rotheart.wall_hit / .stunned | charge ends / stunned (cracked bells) | 1/1 | P0/P1 | 0.6/2 s | 1 | N/Y | N |
| sfx.boss.rotheart.summon | summon Rotlings | 1 | P1 | 1.5 s | 1 | N | N |
| sfx.boss.rotheart.hurt / .death | hit / kill (blight → spirit) | 3/1 | P2/P0 | 0.3/4 s | 2/1 | N | N |

### Gods, shrine, rescues, pickups, world, UI, feedback
| ID | Trigger | Var | Tier | Poly | Loop |
|---|---|---|---|---|---|
| sfx.god.meghra.telegraph / .impact / .aftermath | storm build / strike / rain-sizzle | 1/3/1 | P1/P0/P3 | 1 | N |
| sfx.god.dhoru.telegraph / .impact / .aftermath | snort + scrape / shockwave / rubble | 1/2/1 | P1/P0/P3 | 1 | N |
| sfx.god.vayli.telegraph / .heal / .root | vine creak / rising bells / rope tighten | 1/2/2 | P1/P1/P2 | 1 | N |
| sfx.shrine.{suryak,tamba,kaja,anjor}.purchase | gong / drum roll / wind + flute / fire + crackle, all with a spirit bell tail | 1 | P1 | 1 | N |
| sfx.rescue.cage.creak / .break | near/hitting cage / destroyed | 3/2 | P3/P1 | 1 | N |
| sfx.rescue.freed.{pira,jugnu,hare} | freed jingle (motif variant) | 1 | P1 | 1 | N |
| sfx.companion.pira.chirp_loop / .peck | guiding chirps / interact | 1/3 | P4/P3 | 1 | Y/N |
| sfx.companion.jugnu.shimmer_loop | fireflies near | 1 | P4 | 1 | Y |
| sfx.pickup.meat.collect | earthy "thup" | 3 | P3 | 2 | N |
| sfx.pickup.spirit.magnet | orbs start flying | 1 | P4 | 1 | N |
| sfx.pickup.spirit.collect.{1..8} | each orb; pitch steps up a pentatonic scale per orb in a 0.6 s combo window | 1 + pitch | P3 | 3 | N |
| sfx.world.torch.loop | nearest 2 torches | 1 | P4 | 2 | Y |
| sfx.world.portal.open / .loop / .close | portal lifecycle | 1/1/1 | P2/P4/P3 | 2 | N/Y/N |
| sfx.world.gate.seal_hum / .open | sealed hum / room cleared | 1/1 | P4/P0 | 1 | Y/N |
| amb.grove.{biome}.bed | biome bed + 6 one-shot details | 1+6 | P4 | 1+2 | Y |
| amb.blight.bed | near blight/portals | 1 | P4 | 1 | Y |
| ui.tap / ui.confirm / ui.back / ui.error | wooden clack / bell / soft reverse / dull double knock | 2/1/1/1 | P2 | 2 | N |
| ui.purchase / ui.iap_success | store | 1/1 | P1 | 1 | N |
| ui.ad_reward | reward granted after ad | 1 | P1 | 1 | N |
| ui.upgrade / ui.tab | upgrade / tab switch | 1/2 | P2 | 1 | N |
| sfx.fb.hitstop.crunch | heavy/crit hit-stop start | 3 | P1 | 1 | N |
| sfx.fb.frenzy.tier{1..5} | kill-streak tier (tier 5 adds choir hum) | 1 | P1 | 1 | N |
| sfx.fb.dmgnum.tick | crit damage number, ≤ 1 per 60 ms | 3 | P4 | 2 | N |
| sfx.fb.lowhp.heartbeat_loop | HP < 25%; also low-pass music at 800 Hz | 1 | P1 | 1 | Y |
| sfx.fb.shake.rumble | big screen shakes | 2 | P3 | 1 | N |

### Haptics map
`Input.vibrate_handheld(duration_ms, amplitude)` (amplitude 0–1, −1 = default) needs the VIBRATE permission. Godot's call is a one-shot; rich primitives need a plugin (kyoz/godot-haptics, Mobuos/godot-android-haptics) — deferred.

| Event | Built-in (ms, amp) | Android rich (plugin) | iOS (plugin) | Cooldown |
|---|---|---|---|---|
| Arrow hit (normal) | none | PRIMITIVE_TICK @0.3 | — | — |
| Crit / hit-stop | 20, 0.4 | EFFECT_CLICK | light | 80 ms |
| Player hurt | 40, 0.7 | EFFECT_HEAVY_CLICK | medium | 250 ms |
| Thornback slam / boss wall hit | 60, 0.9 | PRIMITIVE_THUD | heavy | 400 ms |
| God impact | 80, 1.0 | EFFECT_DOUBLE_CLICK | heavy ×2 | 1 s |
| Frenzy tier up | 25, 0.5 | PRIMITIVE_QUICK_RISE | light | 1 s |
| Cage break / rescue | 30, 0.5 | EFFECT_CLICK | medium | — |
| Gate open / room clear | 50, 0.6 | EFFECT_DOUBLE_CLICK | success | — |
| UI tap | none | VIRTUAL_KEY | selection | — |
| Purchase / ad reward | 30, 0.5 | CONFIRM | success | — |

Rules: global budget ≤ 4 pulses/s; setting Off/Low/Full = amplitude ×0 / 0.5 / 1; never vibrate during ads.

## A3. Music (adaptive, vertical layering)

| Cue | Key / mode | Tempo | Meter | Loop | Notes |
|---|---|---|---|---|---|
| Grove combat (5 stems) | D minor pentatonic (D F G A C), drone on D | 96 BPM | 4/4 | 16 bars = 40 s | all stems identical length |
| Camp / shrine | D major pentatonic | 72 BPM | 4/4 | 32 bars ≈ 107 s | flute + soft dholki + crickets |
| Boss (Rotheart) | D Phrygian (E♭ for blight) | 120 BPM | 4/4 | 16 bars = 32 s; stun 8 bars | heart loop locked to beat |
| Victory stinger | D major | free | — | 3–4 s | motif resolved |
| Defeat stinger | D minor, detuned | free | — | 3 s | motif falls |

| Stem | Content | Relax | Build-up | Peak |
|---|---|---|---|---|
| S1 Ambient bed | drone, hums, pads | 0 dB | 0 dB | −3 dB |
| S2 Percussion | dholki/dhol, ghungroo | −∞ | −6 → 0 dB | 0 dB |
| S3 Melody | flute spirit motif | −6 dB | 0 dB | −3 dB |
| S4 Tension | low dhak, detuned glass, sub pulse | −∞ | −12 dB | 0 dB |
| S5 Frenzy/blight | fast ghungroo + dhol rolls | −∞ | −∞ | 0 dB when frenzy ≥ 3 |

Crossfades: stems fade up over 2 beats, down over 4, starting on the next beat; 4 s hysteresis on director state; at most one stem change per bar. Clip switches (grove → boss → camp) use `TRANSITION_FROM_TIME_NEXT_BAR` + cross-fade over 2 beats; stingers use `IMMEDIATE`.

```
AudioStreamPlayer "Music" (bus=Music)
└─ AudioStreamInteractive
   ├─ "camp"    = AudioStreamPlaylist[camp_a, camp_b]
   ├─ "grove"   = AudioStreamSynchronized[S1..S5]  (96 BPM, 64 beats)
   ├─ "boss"    = AudioStreamSynchronized[B1..B4]  (120 BPM, 64 beats)
   ├─ "victory" (auto-advance → return to hold)
   └─ "defeat"
   transitions: ANY→grove/boss/camp: NEXT_BAR, START, CROSS, 2 beats
                ANY→victory/defeat:   IMMEDIATE, START, FADE_OUT, 1 beat
```

OGG import needs BPM, Beat Count and Bar Beats set; OGG loops only from a loop-begin point, so stems are bar-exact with tails wrapped into the head. Memory at ~96 kbps: grove 2.4 MB, boss 1.5 MB, camp 2.6 MB (camp only), stingers 0.3 MB. Low tier: 3-stem variant (S4+S5 merged/muted).

**Placeholder route:** paid-tier-only AI music (Suno free-plan songs are non-commercial and not retroactively licensed; Stability Community License only under US $1M revenue); DIY stems in GarageBand/Logic at exactly 96 BPM × 16 bars are recommended.

**Composer brief / budget** — see the source document; deliverables: grove (5 stems), boss (4 stems), camp (2 tracks), stingers, motif sheet, ~110 SFX IDs; 48 kHz/24-bit masters, bar-exact stems, names = archetype IDs, buyout licence; review on a 3 GB Android speaker + earbuds. Budget tiers ₹60k–1.5L (starter), ₹2–4L (mid), ₹6–12L+ (premium).

## A4. Placeholder pipeline

Sources (shipped builds): CC0 (Kenney packs, Freesound CC0 filter), Sonniss GDC bundles (royalty-free, no redistribution of raw files), or original work. No CC-BY-NC, no "personal use", no YouTube rips. `LICENSES.csv` columns: `file, archetype_id, source, url, author, licence, attribution_required, modified, notes`.

"Make synth sound organic": pitch −3…−7 st → light saturation → band-limit (HPF 120 / LPF 9k) → layer a real transient at −6 dB → short room reverb → fade. Blight version of any grove sound: reverse, pitch −60 cents, long reverb.

`tools/audio_batch.sh raw_dir out_dir` (files `<archetype_id>__<nn>.wav`): trims silence on `sfx.*`/`ui.*`, loudnorm I=−20 (SFX, mono) / −26 (amb, stereo) / fixed gain for `mus.*` (bar-exact), TP −1, then encodes.

## A5. Godot 4.7 implementation standards

- Buses: Master [HardLimiter −1 dB] → Music [EQ −2 dB @ 2.5k, script-ducked], SFX, UI, Ambience [HPF 150], Voice. Script ducking: P0/P1 → Music −5 dB in 30 ms, restore over 400 ms.
- Theme-swappable registry: `AudioManifest` resource with `Dictionary[StringName, AudioEntry]` (stream = `AudioStreamRandomizer` with `random_pitch` ≈ 1.08, volume offset ≈ 2 dB, random-avoid-repeats; bus, tier, poly, pan, cooldown_ms, haptic). Fallback `sfx.player.bow.release.t3` → `sfx.player.bow.release` → silent + debug warning. Theme swap loads streams with `ResourceLoader.load_threaded_request`.
- Pool: 16 players created once (12 `AudioStreamPlayer` + 4 `AudioStreamPlayer2D` for Pan entries); per-entry poly and cooldown; steal lowest tier first (P4 → P3) then oldest; P0 never stolen; if all voices are P0/P1, drop the new P2+ sound. Pooled players keep `max_polyphony` 1.
- Portrait positional rules: non-positional by default; Pan entries use the 2D players with `max_distance` 2× screen height, attenuation 0.5; `2d_panning_strength` 0.35; off-screen enemies play P2+ only, −6 dB.
- Imports: short SFX (< 1 s) WAV 16-bit mono; longer SFX/stingers OGG mono; loops bar-exact; music OGG stereo with BPM/Beat Count/Bar Beats; ambience OGG.
- Lifecycle: paused/focus out → mute Master and open pause; resumed/focus in → fade Master in over 0.4 s, don't auto-unpause. Ads → mute; dismissed → fade in 500 ms. iOS Ambient session; "Let my music play" mutes Music when external music plays. Android audio focus / headphone unplug / calls have no Godot API → test cases, plugin if they fail.
- Settings: music/sfx/ui/amb volumes, haptics level, let-my-music-play.
- Memory budget: low tier music ≤ 3 MB (current cue only), ambience ≤ 1.5, SFX ≤ 5, UI + stingers ≤ 1, total ≤ 10.5 MB (cap 12); mid/high ≤ 16 MB. Enforced by a script; resident MB and voices on the debug overlay.

## Implementation notes (this repo)

See ADR-0007. In short: the audio system is `Services.audio` (no seventh autoload); placeholders are synthesised in-repo by `pipelines/audio/synth.py` (all original, CC0 in `LICENSES.csv`), batch-processed by an ffmpeg-only `tools/audio_batch.sh`; manifests are generated per theme; the music director drives stems from the DDA `IntensityDirector`.
