# localization/

`strings.csv` has `keys,en,hi,mr` columns. Godot imports it into `strings.<locale>.translation` files, which are gitignored and regenerated on import.

The Hindi and Marathi strings are first drafts and need a native-speaker review before release.
Keep 30% room for text expansion, and never bake text into textures (docs/standards.md §C15).
