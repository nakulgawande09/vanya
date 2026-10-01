# ADR-0001: Godot 4.7.2, Compatibility renderer, GDScript

- **Status:** Accepted (2026-10-01)
- **Context:** Solo developer working 12–15 h/week, with existing Godot prototypes. The game is a 2D action roguelite whose floor is 2–3 GB Android devices (Mali/PowerVR). It must ship on Android and iOS and support asset-only theme packs.
- **Decision:** Godot 4.7.2-stable, pinned in `.godot-version`. Use the `gl_compatibility` rendering method on desktop and mobile, and GDScript with strict typing (untyped and unsafe warnings are errors).
- **Consequences:** No license fees, and native PCK theme packs. Ad-tech plugins are community-maintained (see docs/dev-plan.md §2.2). Unity 6 is the fallback if AppLovin MAX or LevelPlay must become the primary mediation.
- **Perf impact:** GLES3 path, with batching-friendly 2D. Swappy frame pacing may not apply to GLES3, so verify frame pacing with Perfetto.
- **Revisit if:** AppLovin MAX or LevelPlay becomes necessary, or iOS OpenGL ES deprecation becomes a blocker.
