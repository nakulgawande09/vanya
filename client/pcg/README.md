# pcg/: room generation (pure logic)

- `chunk_def.gd` and `chunks/*.tres`: 11×6 chunks written as row strings. Symbols: `.` floor, `#` log (always in pairs), `I` idol, `~` blight roots, `P` portal spot, `C` cage spot.
- `room_rules.gd` / `room_rules.tres`: every tunable (families, portal and torch counts, distances, open ratio, fallback and tutorial rooms).
- `room_generator.gd`: deterministic for (seed, grove). Edge-matches and mirrors chunks, places portals, cage, torches and bushes, then validates. It reseeds up to 5 times, then falls back to a hand-made room.
- `room_validator.gd`: reachability, open floor, portal path length, gate apron.
- `room_plan.gd`: the result: a 13×30 tile grid and placements, plus `flow_codes()` for pathing.

To add a chunk, write a `.tres`, add it to `room_rules.tres`, run the unit tests, and regenerate `tests/golden/rooms.json` if the digests change on purpose.
