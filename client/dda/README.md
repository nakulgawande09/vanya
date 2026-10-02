# dda/: adaptive difficulty (pure logic, dev-plan §7)

- `skill_rating.gd`: Elo rating R against room difficulty D; performance S; K is 40 for the first 10 rooms, then 24; anti-sandbag.
- `dda_rails.gd`: target difficulty → wave budget scale, with ±8%/room, ±20%/arc and a 0.75–1.25 range; mercy after 2 deaths, a relief room after 3; spirit supply 2–12%.
- `intensity_director.gd`: build-up / peak / relax pacing for waves.

`GroveRun` rates each room once (on clear, or on the first death), saves the rating in the profile, and logs `room_result`. The player's Difficulty setting picks the target success rate. "Adaptive challenge: Off" fixes the scale at 1.0.
