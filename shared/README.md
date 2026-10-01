# shared/ (placeholder)

The single source of truth shared by client and server:
- `schemas/`: arc plan, telemetry, theme manifest and save schemas
- `enums/`: archetypes, biomes and modifiers, code-generated to GDScript and Python
- `golden_seeds/`: PCG parity fixtures

Until codegen exists, archetype IDs are maintained by hand in `client/core/archetypes/ids.gd`.
See [docs/standards.md §A.1](../docs/standards.md).
