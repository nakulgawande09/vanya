extends Node
## Typed global signals for cross-scene events only. Siblings talk through their parent;
## everything else is "call down, signal up" (docs/standards.md §A.8).

@warning_ignore_start("unused_signal")
signal boot_completed
signal run_started(run_seed: int)
signal run_ended(cleared: bool, groves_cleared: int)
signal purchase_granted(product_id: StringName)
signal quality_changed(old_rung: int, new_rung: int)
signal theme_changed(theme_id: StringName)
@warning_ignore_restore("unused_signal")
