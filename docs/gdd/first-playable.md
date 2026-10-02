# First playable loop (provisional numbers)

Written before the prototypes were shared. Every tunable lives in typed `.tres` data under `client/data/`, so balancing is a data change. When the prototype is merged, its feel should win over these numbers.

## Loop
Camp → "Enter the grove" → grove 1, 2, … → the hunter falls → defeat (watch an ad to revive, once per grove) → back to camp, where meat and spirit are banked.

- **Room:** 13 × 30 tiles of 32 px, generated from chunk families (open glade, idol maze, river split, ring arena, boss hollow) with logs and idols as obstacles and blight roots as slow zones (see `client/pcg/`). The gate is at the top; the hunter starts at the bottom.
- **Waves:** 3 per room, through 2–4 spawn portals, with 5 s of relax between waves. When the last wave falls, the gate opens; walking into it loads the next grove.
- **Combat:**
  - The floating joystick (left thumb) moves the hunter, who starts with 150 px/s speed and 100 HP.
  - The auto-aim bow shoots the nearest beast within 240 px.
  - After a hit, the hunter gets 0.6 s of i-frames.
- **Rescue:** Stand next to a cage for 0.9 s for +3 spirit. The first bird cage brings Pira (pecks for 6 every 1 s). The firefly jar brings Jugnu (×1.33 light, and +1 HP every 0.75 s once nothing has touched the hunter for 2 s).
- **Every 5th grove:** Rotheart (1200 HP) runs stalk → telegraph 0.75 s → charge 0.65 s → stunned 2.5 s after hitting a wall (heart takes ×2 damage). Every third cycle it summons 2 Rotlings.

## Beasts (`data/archetypes/*.tres`)
| | HP | Speed | Contact | Hitbox r | Meat | Spirit % | Budget | From grove |
|---|---|---|---|---|---|---|---|---|
| Rotling (swarm) | 30 | 72 | 8 | 14 | 2 | 5 | 1 | 1 |
| Thornback (tank) | 150 | 42 | 16 | 26 | 6 | 30 | 5 | 2 |
| Wisp (ranged: orb 10 dmg, 0.4 s tell, every 2.2 s) | 50 | 56 | 6 | 16 | 4 | 20 | 3 | 3 |
| Rotheart (boss: charge 30 dmg) | 1200 | 48 | 25 | 58 | 40 | 100 | — | 5 |

Room budget = 10 + 4 × (grove − 1), multiplied by the DDA scale (0.75–1.25; see `client/dda/`). Waves split it 25 / 35 / 40 %. Mix weights are Rotling 6, Thornback 1.5, Wisp 2. The intensity director holds spawns at peaks and makes the next wave wait for its relax window.

## Economy
- **Arrows (meat):** Stone 10 dmg (free); Flint 14 dmg (30 meat); Bone 18 dmg and pierces one beast (70 meat); Rapid bow 14 dmg, twin shot (150 meat).
- **Gods (spirit in battle):** Meghra 3 spirit, 9 s cooldown, 60 dmg to the 6 nearest beasts; Dhoru 3 spirit, 8 s, 20 dmg + knockback in 150 px and clears orbs; Vayli 2 spirit, 10 s, heals 35 and roots beasts in 140 px for 3 s.
- **Shrine (banked spirit, levels cost 4 · 8 · 14 · 22 · 32):** Suryak +10% damage, Tamba +20 HP, Kaja +8% speed, Anjor +12% light — each per level.

## Feel, settings, onboarding
- **Hit-stop:** 70 ms when the hunter is hit, 50 ms on elite kills, 120 ms on a boss kill or stun.
- **Hurt feedback:** red vignette and 25 ms vibration (both follow the settings).
- **Juice:** swarm units squash on hit; pickups fly to their HUD pill; arrows leave trails on High/Medium.
- **Pause:** the HUD button, Android back and backgrounding all open it.
- **Settings:** hand, shake, flashes, damage numbers, vibration, language (en/hi/mr), difficulty, adaptive challenge, graphics, world.
- **First-run tutorial grove:** move → bow → free the bird → call Meghra → gate, with a Skip button.

## Deliberate gaps (next)
- Audio: no SFX or music yet (the bible has no audio). This is the biggest remaining feel gap.
- Re-fitting the DDA constants from playtest `room_result` data; the server-side Python mirror of the generator.
- Real AdMob, billing, Firebase and the ADPF thermal bridge (fakes are wired through `Services`).
