extends Node
## Asset registry. Game code refers to art by asset id ("doctor_volkov", "ambulance"),
## never by file path. Lookup convention: res://art/<kind>/<id>.<ext> — first match wins,
## so dropping doctor_volkov.png next to doctor_volkov.svg replaces the placeholder
## without touching any game logic.

const ART_ROOT := "res://art/"
const EXTENSIONS := ["png", "webp", "jpg", "svg"]

var _cache: Dictionary = {}
var _fonts: Dictionary = {}


func texture(kind: String, id: String, svg_scale: float = 2.0) -> Texture2D:
	var key := "%s/%s@%s" % [kind, id, svg_scale]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	for ext in EXTENSIONS:
		var path := "%s%s/%s.%s" % [ART_ROOT, kind, id, ext]
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			continue
		tex = _load(path, ext, svg_scale)
		if tex != null:
			break
	_cache[key] = tex
	return tex


func has_texture(kind: String, id: String) -> bool:
	return texture(kind, id) != null


func icon(id: String) -> Texture2D:
	var t := texture("icons", id, 2.0)
	if t == null and id != "unknown":
		return texture("icons", "unknown", 2.0)
	return t


func portrait(id: String) -> Texture2D:
	return texture("characters", id, 2.0)


## Head-and-shoulders crop for small UI slots. Works for any portrait size (normalised region).
func portrait_face(id: String) -> Texture2D:
	var key := "face/" + id
	if _cache.has(key):
		return _cache[key]
	var full := portrait(id)
	if full == null:
		return null
	var a := AtlasTexture.new()
	a.atlas = full
	var w := float(full.get_width())
	var h := float(full.get_height())
	a.region = Rect2(w * 0.2, h * 0.17, w * 0.6, h * 0.62)
	_cache[key] = a
	return a


func _load(path: String, ext: String, svg_scale: float) -> Texture2D:
	if ext == "svg":
		# SVGs are rasterised at runtime so placeholders stay crisp at any UI scale.
		var img := Image.new()
		if img.load_svg_from_string(FileAccess.get_file_as_string(path), svg_scale) != OK:
			return null
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		return load(path)
	var img2 := Image.load_from_file(path)
	return ImageTexture.create_from_image(img2) if img2 else null


## UI fonts. weight: 400 regular, 500 medium, 700 bold. mono = numbers / clocks.
func font(style: String = "regular") -> Font:
	if _fonts.has(style):
		return _fonts[style]
	var f: Font
	match style:
		"mono":
			f = _font_file("res://art/ui/fonts/IBMPlexMono-Regular.ttf")
		"mono_bold":
			f = _font_file("res://art/ui/fonts/IBMPlexMono-SemiBold.ttf")
		"display", "display_light", "display_bold":
			var v0 := FontVariation.new()
			v0.base_font = _font_file("res://art/ui/fonts/Oswald-Variable.ttf")
			v0.variation_opentype = {"wght": {"display": 500, "display_light": 300, "display_bold": 650}[style]}
			f = v0
		"serif":
			f = _font_file("res://art/ui/fonts/PT_Serif-Web-Regular.ttf")
		"serif_italic":
			f = _font_file("res://art/ui/fonts/PT_Serif-Web-Italic.ttf")
		"narrow":
			f = _font_file("res://art/ui/fonts/PT_Sans-Narrow-Web-Bold.ttf")
		_:
			var base := _font_file("res://art/ui/fonts/RobotoCondensed-Variable.ttf")
			var v := FontVariation.new()
			v.base_font = base
			var w: int = {"regular": 400, "medium": 500, "bold": 700, "black": 800}.get(style, 400)
			v.variation_opentype = {"wght": w}
			f = v
	_fonts[style] = f
	return f


func _font_file(path: String) -> Font:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Font:
			return r
	var ff := FontFile.new()
	ff.load_dynamic_font(path)
	return ff
