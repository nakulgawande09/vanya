extends SceneTree
## Renders the Android launcher icons from client/icon.svg (the bible's Play Store icon), so no
## binary images live in git. Run before an Android export:
##   godot --headless --path client -s ../tools/render_icons.gd
## Writes client/platform/android/icons/{main_192,adaptive_fg_432,adaptive_bg_432,adaptive_mono_432}.png

const OUT: String = "res://platform/android/icons/"
const ICON: String = "res://icon.svg"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var svg: String = FileAccess.get_file_as_string(ICON)
	var full: Image = Image.new()
	full.load_svg_from_string(svg, 192.0 / 512.0)
	full.save_png(OUT + "main_192.png")
	# Adaptive icons: the art inside the central 66% safe zone over a flat geru background.
	var art: Image = Image.new()
	art.load_svg_from_string(svg, 288.0 / 512.0)
	var fg: Image = Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(72, 72))
	fg.save_png(OUT + "adaptive_fg_432.png")
	var bg: Image = Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(art.get_pixel(art.get_width() / 2, 6))
	bg.save_png(OUT + "adaptive_bg_432.png")
	var mono: Image = fg.duplicate() as Image
	for y: int in mono.get_height():
		for x: int in mono.get_width():
			var c: Color = mono.get_pixel(x, y)
			mono.set_pixel(x, y, Color(1, 1, 1, c.a))
	mono.save_png(OUT + "adaptive_mono_432.png")
	print("render_icons: wrote 4 launcher icons")
	quit()
