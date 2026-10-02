extends SceneTree
## Prints the painted bounds of SVG files, for pipelines/asset/extract_bible.py.
## Usage: godot --headless -s tools/svg_bounds.gd -- <list.txt> <out.json>
## Each SVG is rasterized at its own width/height; the result maps path -> [x, y, w, h] in texture px.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var paths: PackedStringArray = FileAccess.get_file_as_string(args[0]).strip_edges().split("\n")
	var out: Dictionary = {}
	for path: String in paths:
		var img: Image = Image.new()
		var err: Error = img.load_svg_from_string(FileAccess.get_file_as_string(path), 1.0)
		if err != OK:
			push_error("svg_bounds: cannot rasterize %s" % path)
			continue
		var r: Rect2i = img.get_used_rect()
		out[path] = [r.position.x, r.position.y, r.size.x, r.size.y]
	var f: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	quit()
