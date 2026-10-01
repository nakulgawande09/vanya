class_name Ids
## Archetype IDs. Immutable once shipped, so never rename a value; add new ones instead.
## Hand-maintained until shared/enums codegen exists (docs/standards.md §A.1).

# Enemies (gameplay archetype in comments)
const ROTLING: StringName = &"rotling"          # SWARM
const THORNBACK: StringName = &"thornback"      # TANK
const WISP: StringName = &"wisp"                # RANGED
const ROTHEART: StringName = &"rotheart"        # BOSS

# Player
const HUNTER: StringName = &"hunter"

# Run gods (BUFF_GOD_1..3)
const MEGHRA: StringName = &"meghra"
const DHORU: StringName = &"dhoru"
const VAYLI: StringName = &"vayli"

# Meta gods at the camp shrine (META_GOD_1..4)
const SURYAK: StringName = &"suryak"
const TAMBA: StringName = &"tamba"
const KAJA: StringName = &"kaja"
const ANJOR: StringName = &"anjor"

# Guides (GUIDE_1..2)
const PIRA: StringName = &"pira"
const JUGNU: StringName = &"jugnu"

# Currencies (CURRENCY_A/B)
const MEAT: StringName = &"meat"
const SPIRIT: StringName = &"spirit"

# World objects
const CAGE: StringName = &"cage"
const TORCH: StringName = &"torch"
const IDOL: StringName = &"idol"
const EXIT_GATE: StringName = &"exit_gate"
const PORTAL: StringName = &"portal"

const ENEMIES: Array[StringName] = [ROTLING, THORNBACK, WISP, ROTHEART]
const RUN_GODS: Array[StringName] = [MEGHRA, DHORU, VAYLI]
const META_GODS: Array[StringName] = [SURYAK, TAMBA, KAJA, ANJOR]
const GUIDES: Array[StringName] = [PIRA, JUGNU]
const CURRENCIES: Array[StringName] = [MEAT, SPIRIT]
