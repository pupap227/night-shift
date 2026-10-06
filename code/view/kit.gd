class_name Kit
extends RefCounted
## Visual language of the game shell (replaces the old dashboard UIStyle).
## Night, wet concrete, paper, old enamel signs. Red only for emergencies.

const INK := Color("06090e")
const NIGHT := Color("0b1119")
const NIGHT_2 := Color("111a25")
const STEEL := Color("2a3442")
const STEEL_HI := Color("4a5a6d")
const PAPER := Color("e9e1cc")
const PAPER_DIM := Color("b9b09a")
const TEXT := Color("e6e9ec")
const TEXT_DIM := Color("9aa6b2")
const TEXT_FAINT := Color("5d6976")
const WARM := Color("f2b45a")
const RED := Color("e0483f")
const RED_DEEP := Color("8d1c1c")
const AMBER := Color("e0b043")
const GREEN := Color("62c27a")
const COLD := Color("9fc7e8")


static func font(style: String) -> Font:
	return Assets.font(style)


static func label(text: String, size: int, color: Color = TEXT, style: String = "regular") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Assets.font(style))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 6, margin: float = 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


static func big_button(text: String, kind: String = "primary", size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Assets.font("display"))
	b.add_theme_font_size_override("font_size", size)
	var bg := Color("1c2633")
	var fg := TEXT
	var border := STEEL_HI
	match kind:
		"emergency":
			bg = Color("a3231f")
			border = Color("e0483f")
			fg = Color.WHITE
		"paper":
			bg = PAPER
			border = PAPER
			fg = INK
		"ghost":
			bg = Color(1, 1, 1, 0.04)
			border = STEEL
			fg = TEXT_DIM
	var n := box(bg, border, 1, 8)
	n.content_margin_left = 16
	n.content_margin_right = 16
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = bg.lightened(0.08)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = bg.darkened(0.2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	return b


static func icon(id: String, sz: float, col: Color = TEXT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.icon(id)
	t.custom_minimum_size = Vector2(sz, sz)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = col
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func mins(m: float) -> String:
	var v := int(ceil(maxf(0.0, m)))
	if v < 60:
		return "%d мин" % v
	return "%d ч %02d" % [v / 60, v % 60]


static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("−" if v < 0 else "") + s + out


static func cond_color(v: float) -> Color:
	if v < 30.0:
		return RED
	if v < 60.0:
		return AMBER
	return Color("8fc79c")


## Role summary of what a patient pipeline needs: [{label, count, icon}]
static func role_icon(label: String) -> String:
	var l := label.to_lower()
	if l.contains("хирург"):
		return "scalpel"
	if l.contains("анестез"):
		return "ecg"
	if l.contains("кардиол"):
		return "heart"
	if l.contains("медсестр"):
		return "cross"
	if l.contains("санитар"):
		return "staff"
	if l.contains("охран"):
		return "shield"
	if l.contains("диагност"):
		return "flask"
	return "patients"
