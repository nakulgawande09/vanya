class_name ChunkDef
extends Resource
## An 11 × 6 slice of a grove's interior, authored as row strings:
##   .  floor            #  fallen log (obstacle, always in horizontal pairs)
##   I  spirit idol (obstacle)   ~  blight roots (slow zone)
##   P  spawn-portal spot   C  cage spot
## The generator stacks three chunks between the fixed gate and start strips (dev-plan §6.2).

const WIDTH: int = 11
const HEIGHT: int = 6

@export var id: StringName = &""
@export var family: StringName = &"open_glade"
@export var rows: PackedStringArray = PackedStringArray()
@export var weight: float = 1.0


func is_valid() -> bool:
	if rows.size() != HEIGHT:
		return false
	for r: String in rows:
		if r.length() != WIDTH:
			return false
	return true


func at(x: int, y: int, mirrored: bool) -> String:
	return rows[y][WIDTH - 1 - x if mirrored else x]


## Bit mask of open (non-obstacle) columns in a row, for edge matching between chunks.
func open_mask(y: int) -> int:
	var mask: int = 0
	for x: int in WIDTH:
		var c: String = rows[y][x]
		if c != "#" and c != "I":
			mask |= 1 << x
	return mask
