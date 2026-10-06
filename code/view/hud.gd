class_name Hud
extends Control
## Top of the screen, floating over the map on a fade (not a panel):
## clock · alarm lamp · money · time controls. Desktop also shows beds and trust.

signal menu_pressed

var _clock: Label
var _sub: Label
var _alarm: AlarmLamp
var _money: Label
var _extra: HBoxContainer
var _beds: Label
var _trust: Label
var _pause: Button
var _speed: Button
var _menu: Button
var _row: HBoxContainer
var _bg: TextureRect
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.015, 0.025, 0.95))
	g.set_color(1, Color(0.01, 0.015, 0.025, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_bg.texture = gt
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 14)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	var clock := VBoxContainer.new()
	clock.add_theme_constant_override("separation", -8)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(clock)
	_sub = Kit.label("НОЧЬ · ДЕНЬ 12", 11, Kit.TEXT_DIM, "display_bold")
	clock.add_child(_sub)
	_clock = Kit.label("22:00", 32, Kit.TEXT, "display_bold")
	clock.add_child(_clock)
	_alarm = AlarmLamp.new()
	_row.add_child(_alarm)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(sp)
	_extra = HBoxContainer.new()
	_extra.add_theme_constant_override("separation", 18)
	_extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_extra)
	_beds = _stat(_extra, "bed")
	_trust = _stat(_extra, "trust")
	_money = _stat(_row, "money")
	_money.get_parent().get_child(0).custom_minimum_size = Vector2(14, 14)
	_pause = _round_button("pause")
	_pause.pressed.connect(func():
		Game.toggle_pause()
		Audio.play("click", -8.0))
	_row.add_child(_pause)
	_speed = _round_button("")
	_speed.pressed.connect(func():
		Game.set_speed(Game.speed % 3 + 1)
		Audio.play("click", -8.0))
	_row.add_child(_speed)
	_menu = _round_button("load")
	_menu.icon = null
	_menu.text = "≡"
	_menu.pressed.connect(func(): menu_pressed.emit())
	_row.add_child(_menu)
	Game.time_changed.connect(func(_m): _refresh())
	Game.stats_changed.connect(_refresh)
	Game.speed_changed.connect(func(_s, _p): _refresh())
	_refresh()


func _stat(parent: Control, icon: String) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.icon(icon, 16, Kit.TEXT_DIM))
	var l := Kit.label("", 17, Kit.TEXT, "display")
	h.add_child(l)
	parent.add_child(h)
	return l


func _round_button(icon: String) -> Button:
	var b := Button.new()
	if icon != "":
		b.icon = Assets.icon(icon)
		b.expand_icon = true
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Kit.font("display_bold"))
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Kit.TEXT)
	var n := Kit.box(Color(0.05, 0.07, 0.1, 0.8), Color(1, 1, 1, 0.14), 1, 22, 10)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	var p := Kit.box(Color(0.12, 0.16, 0.22, 0.9), Color(1, 1, 1, 0.3), 1, 22, 10)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func relayout(compact: bool) -> void:
	_bg.size = Vector2(size.x, size.y + 50)
	_bg.position = Vector2(0, -Screen.safe.position.y)
	_bg.size.y += Screen.safe.position.y
	_row.position = Vector2(14 + Screen.safe.position.x, 6)
	_row.size = Vector2(size.x - 28 - Screen.safe.position.x - (Screen.size.x - Screen.safe.end.x), size.y - 6)
	_extra.visible = not compact
	_alarm.compact = compact and Screen.mode == Screen.Mode.PORTRAIT
	_row.add_theme_constant_override("separation", 8 if compact else 14)
	for b in [_pause, _speed, _menu]:
		b.custom_minimum_size = Vector2(40, 40) if compact else Vector2(44, 44)
	_clock.add_theme_font_size_override("font_size", 28 if compact else 34)
	_menu.visible = true


func _refresh() -> void:
	_clock.text = Game.clock_string()
	_sub.text = "НОЧЬ · ДЕНЬ %d" % Game.day
	_money.text = Kit.money(Game.money) + " ₽"
	_beds.text = "%d св." % Game.free_beds()
	_trust.text = str(Game.reputation)
	var held := not Game.is_time_flowing()
	_pause.icon = Assets.icon("play" if held else "pause")
	_speed.text = "×%d" % Game.speed


func _process(delta: float) -> void:
	_t += delta
	if not Game.is_time_flowing() and Game.running:
		_clock.modulate.a = 1.0 if fmod(_t, 1.0) < 0.6 else 0.45
	else:
		_clock.modulate.a = 1.0


class AlarmLamp extends Control:
	var compact := false:
		set(v):
			compact = v
			custom_minimum_size = Vector2(48 if v else 118, 44)
	var _t := 0.0
	var _v := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(118, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tooltip_text = "Тревога растёт, когда пациенты ждут и умирают"

	func _process(delta: float) -> void:
		_t += delta
		_v = lerpf(_v, Game.alarm, minf(1.0, delta * 3.0))
		queue_redraw()

	func _draw() -> void:
		var lvl := Game.alarm_level
		var cols := [Color("8fa6bb"), Kit.AMBER, Kit.RED]
		var col: Color = cols[lvl]
		var c := Vector2(18, size.y * 0.5)
		var pulse := 0.5 + 0.5 * sin(_t * (2.0 + lvl * 3.0))
		if lvl > 0:
			draw_circle(c, 17 + 4 * pulse, Color(col, 0.18 * pulse))
		draw_circle(c, 13, Color(0.04, 0.05, 0.07))
		draw_circle(c, 10, col.darkened(0.3 - 0.3 * pulse if lvl > 0 else 0.4))
		draw_circle(c - Vector2(3, 3), 3, Color(1, 1, 1, 0.35))
		var labels := ["СПОКОЙНО", "НАПРЯЖЕНИЕ", "КРИЗИС"]
		if compact:
			for i in 3:
				var on2 := i <= lvl and (_v > 5.0 or i == 0)
				draw_rect(Rect2(34, size.y * 0.5 - 9 + (2 - i) * 7, 6, 5), cols[i] if on2 else Color(1, 1, 1, 0.12))
			return
		draw_string(Kit.font("display_bold"), Vector2(38, size.y * 0.5 - 2), labels[lvl], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col.lightened(0.15))
		for i in 3:
			var on := i <= lvl and (_v > 5.0 or i == 0)
			draw_rect(Rect2(38 + i * 24, size.y * 0.5 + 6, 20, 4), cols[i] if on else Color(1, 1, 1, 0.12))
