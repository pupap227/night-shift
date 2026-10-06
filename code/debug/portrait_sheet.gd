extends Node
## Renders all character portraits into one contact sheet (headless-safe, CPU only).

func _ready() -> void:
	var ids: Array = Game.db.characters.keys()
	var sheet := Image.create(300 * 4, 360 * 2, false, Image.FORMAT_RGBA8)
	for i in ids.size():
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string("res://art/characters/%s.svg" % ids[i]), 1.5)
		if err != OK:
			print("FAIL ", ids[i])
			continue
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, 300, 360), Vector2i((i % 4) * 300, (i / 4) * 360))
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://sheet.png"
	sheet.save_png(out)
	print("sheet saved ", out)
	get_tree().quit()
