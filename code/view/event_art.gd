class_name EventArt
extends Control
## Procedural illustration for an event header — a placeholder for painted art
## (res://art/events/<event_id>.png replaces it automatically). Two passes:
## this control paints shapes, a child with additive blending paints light.

var motif := "road"
var event_id := ""
var _time := 0.0
var _drops: Array = []
var _tex: Texture2D
var _glow_tex: Texture2D
var _glow: Control


func setup(ev: EventInstance) -> void:
	event_id = ev.data.id
	motif = {"ambulance": "road", "heart": "road", "police": "police", "biohazard": "plant", "alarm": "crash",
		"phone": "room", "flask": "lab", "shield": "door", "admin": "office"}.get(ev.data.icon, "road")
	_tex = Assets.texture("events", event_id)
	_glow_tex = CityGlow.radial_texture()
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(event_id)
	for i in 90:
		_drops.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.3)))
	_glow = Control.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.draw.connect(func(): _lights(_glow))
	add_child(_glow)


func _process(delta: float) -> void:
	_time += delta
	_glow.size = size
	queue_redraw()
	_glow.queue_redraw()


func _beacon(phase: float = 0.0) -> Color:
	return Color(0.3, 0.5, 1.0) if fmod(_time * 2.4 + phase, 1.0) < 0.5 else Color(1.0, 0.16, 0.12)


func _gl(c: Control, at: Vector2, r: Vector2, col: Color) -> void:
	c.draw_texture_rect(_glow_tex, Rect2(at - r, r * 2.0), false, col)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
		_rain(w, h)
		return
	var hz := h * 0.56
	if motif in ["room", "office", "lab", "door"]:
		match motif:
			"lab":
				_lab(w, h)
			"door":
				_door(w, h)
			_:
				_room(w, h)
	else:
		_sky(w, hz)
		_skyline(w, hz)
		if motif == "plant":
			_plant(w, h, hz)
		else:
			_road(w, h, hz)
	_rain(w, h)
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.6), Vector2(w, h * 0.6), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.043, 0.067, 0.098, 1), Color(0.043, 0.067, 0.098, 1)]))


func _sky(w: float, hz: float) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hz), Vector2(0, hz)]),
		PackedColorArray([Color("070d1a"), Color("0a1222"), Color("2a2430"), Color("231f2c")]))


func _skyline(w: float, hz: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var x := -20.0
	while x < w:
		var bw := rng.randf_range(34, 80)
		var bh := rng.randf_range(18, hz * 0.55)
		draw_rect(Rect2(x, hz - bh, bw - 3, bh), Color("0d1119"))
		for wy in range(int(hz - bh + 5), int(hz - 4), 7):
			for wx in range(int(x + 4), int(x + bw - 8), 6):
				if rng.randf() < 0.14:
					draw_rect(Rect2(wx, wy, 2.5, 3), Color(0.95, 0.72, 0.42, rng.randf_range(0.35, 0.85)))
		x += bw


func _road(w: float, h: float, hz: float) -> void:
	var vp := Vector2(w * 0.4, hz)
	draw_rect(Rect2(0, hz, w, h - hz), Color("0a0d12"))
	draw_colored_polygon(PackedVector2Array([vp + Vector2(-6, 0), vp + Vector2(6, 0), Vector2(w * 1.1, h), Vector2(-w * 0.25, h)]), Color("12161c"))
	# Lane dashes in perspective
	for i in 7:
		var t0 := pow(float(i) / 7.0, 1.8)
		var t1 := pow((float(i) + 0.45) / 7.0, 1.8)
		var p0 := vp.lerp(Vector2(w * 0.42, h), t0)
		var p1 := vp.lerp(Vector2(w * 0.42, h), t1)
		draw_line(p0, p1, Color(0.85, 0.82, 0.7, 0.35), 1.0 + t1 * 4.0)
	# Street lamps receding on the right
	for i in 5:
		var t := pow((i + 1) / 5.5, 1.6)
		var base := vp.lerp(Vector2(w * 1.02, h * 1.05), t)
		var ph := 12.0 + 90.0 * t
		draw_line(base, base - Vector2(0, ph), Color("1b1f25"), 1.0 + 2.5 * t)
		draw_line(base - Vector2(0, ph), base - Vector2(14 * t, ph + 2), Color("1b1f25"), 1.0 + 2.0 * t)
	if motif == "crash":
		_bus(w, h, hz)
	_vehicle(Vector2(w * 0.33, h * 0.78), motif == "police")


func _vehicle(c: Vector2, police: bool) -> void:
	# 3/4 front view van: front face + side.
	var body := Color("d6d0be") if not police else Color("2c3440")
	var side := body.darkened(0.25)
	var fw := 66.0
	var fh := 48.0
	var front := Rect2(c.x - fw * 0.5, c.y - fh, fw, fh)
	draw_colored_polygon(PackedVector2Array([front.position + Vector2(fw, 0), front.position + Vector2(fw + 70, -16), front.position + Vector2(fw + 70, fh - 18), front.end]), side)
	draw_rect(front, body)
	draw_rect(Rect2(front.position + Vector2(6, 6), Vector2(fw - 12, 17)), Color("101820"))
	draw_colored_polygon(PackedVector2Array([front.position + Vector2(fw + 6, 6), front.position + Vector2(fw + 34, -3), front.position + Vector2(fw + 34, 12), front.position + Vector2(fw + 6, 21)]), Color("141c25"))
	if not police:
		draw_rect(Rect2(front.position.x, c.y - 20, fw, 6), Color(0.78, 0.12, 0.1))
		draw_colored_polygon(PackedVector2Array([front.position + Vector2(fw, fh - 20), front.position + Vector2(fw + 70, fh - 36), front.position + Vector2(fw + 70, fh - 30), front.position + Vector2(fw, fh - 14)]), Color(0.65, 0.1, 0.09))
		draw_rect(Rect2(front.position.x + fw * 0.5 - 6, c.y - 36, 12, 12), Color(0.85, 0.12, 0.1))
	draw_rect(Rect2(front.position.x + 4, c.y - 12, 12, 7), Color(1, 0.96, 0.85))
	draw_rect(Rect2(front.end.x - 16, c.y - 12, 12, 7), Color(1, 0.96, 0.85))
	draw_rect(Rect2(front.position.x + 8, front.position.y - 7, fw - 16, 7), _beacon())
	draw_rect(Rect2(c.x - 30, c.y, 14, 8), Color("07090c"))
	draw_rect(Rect2(c.x + 16, c.y, 14, 8), Color("07090c"))


func _bus(w: float, h: float, hz: float) -> void:
	var p := Vector2(w * 0.68, h * 0.74)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-90, 0), p + Vector2(90, -16), p + Vector2(96, -62), p + Vector2(-84, -50)]), Color("2a2f2c"))
	for i in 6:
		draw_rect(Rect2(p.x - 72 + i * 26, p.y - 46 - i * 2, 18, 14), Color(0.9, 0.7, 0.4, 0.25 if i % 2 == 0 else 0.08))


func _plant(w: float, h: float, hz: float) -> void:
	draw_rect(Rect2(0, hz, w, h - hz), Color("0a0d0f"))
	for i in 3:
		var cx := w * (0.42 + i * 0.17)
		var ch := hz * (0.95 - i * 0.18)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 9, hz), Vector2(cx + 9, hz), Vector2(cx + 6, hz - ch), Vector2(cx - 6, hz - ch)]), Color("1b1513"))
		for k in 8:
			var t := fmod(_time * 0.12 + k / 8.0 + i * 0.3, 1.0)
			draw_circle(Vector2(cx + t * 110, hz - ch - 8 - t * 50), 6 + t * 26, Color(0.5, 0.62, 0.45, 0.13 * (1.0 - t)))
	draw_rect(Rect2(w * 0.25, hz - 40, w * 0.6, 40), Color("12161a"))
	for i in 12:
		draw_rect(Rect2(w * 0.27 + i * w * 0.048, hz - 30, 8, 10), Color(1.0, 0.65, 0.3, 0.5 if i % 3 else 0.1))
	for i in 30:
		var fx := i * w / 30.0
		draw_line(Vector2(fx, h * 0.72), Vector2(fx, h), Color("0c0f12"), 2.0)
	draw_line(Vector2(0, h * 0.74), Vector2(w, h * 0.74), Color("0c0f12"), 2.0)


func _room(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color("130f0c"))
	var win := Rect2(w * 0.56, h * 0.08, w * 0.34, h * 0.6)
	draw_rect(win, Color("0a1426"))
	for i in 12:
		draw_rect(Rect2(win.position.x + 8 + i * (win.size.x - 16) / 12.0, win.position.y + win.size.y * 0.55, 5, 5), Color(0.95, 0.7, 0.4, 0.55))
	draw_rect(win, Color("2b241f"), false, 5.0)
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("2b241f"), 4.0)
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("21180f"))
	var p := Vector2(w * 0.28, h * 0.7)
	draw_rect(Rect2(p.x - 36, p.y - 22, 72, 22), Color("2d1b17"))
	draw_circle(p + Vector2(0, -11), 9, Color("3c2622"))
	draw_rect(Rect2(p.x - 42, p.y - 34, 84, 11), Color("2d1b17"))
	draw_line(Vector2(w * 0.12, h * 0.7), Vector2(w * 0.12, h * 0.3), Color("2a221c"), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.05, h * 0.3), Vector2(w * 0.19, h * 0.3), Vector2(w * 0.16, h * 0.2), Vector2(w * 0.08, h * 0.2)]), Color("3a2a1c"))


func _lab(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color("0c1318"))
	draw_rect(Rect2(w * 0.12, h * 0.68, w * 0.76, 7), Color("4a555e"))
	for i in 10:
		var tx := w * 0.17 + i * w * 0.066
		draw_rect(Rect2(tx, h * 0.36, 11, h * 0.32), Color(0.75, 0.85, 0.95, 0.2))
		draw_rect(Rect2(tx, h * 0.52, 11, h * 0.16), Color(0.65, 0.12, 0.12, 0.7) if i % 3 != 1 else Color(0.2, 0.25, 0.3, 0.6))


func _door(w: float, h: float) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.62, h * 0.22), Vector2(w * 0.38, h * 0.22)]), PackedColorArray([Color("15191d"), Color("15191d"), Color("1d2227"), Color("1d2227")]))
	draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(w, h), Vector2(w * 0.62, h * 0.78), Vector2(w * 0.38, h * 0.78)]), PackedColorArray([Color("0f1215"), Color("0f1215"), Color("1a1f24"), Color("1a1f24")]))
	draw_rect(Rect2(w * 0.38, h * 0.22, w * 0.24, h * 0.56), Color(0.92, 0.88, 0.78, 0.9))
	var m := Vector2(w * 0.5, h * 0.78)
	draw_colored_polygon(PackedVector2Array([m + Vector2(-14, 0), m + Vector2(14, 0), m + Vector2(10, -70), m + Vector2(-10, -70)]), Color("0b0c0d"))
	draw_circle(m + Vector2(0, -80), 11, Color("0b0c0d"))


func _rain(w: float, h: float) -> void:
	for d in _drops:
		var px := fmod(d.x * w + _time * 50.0 * d.z, w + 40) - 20
		var py := fmod(d.y * h + _time * 460.0 * d.z, h + 20) - 10
		draw_line(Vector2(px, py), Vector2(px - 3, py + 13 * d.z), Color(0.75, 0.82, 0.95, 0.2), 1.0)


## Additive light pass.
func _lights(c: Control) -> void:
	var w := size.x
	var h := size.y
	if _tex:
		return
	var hz := h * 0.56
	match motif:
		"road", "police", "crash":
			var vp := Vector2(w * 0.4, hz)
			for i in 5:
				var t := pow((i + 1) / 5.5, 1.6)
				var base := vp.lerp(Vector2(w * 1.02, h * 1.05), t)
				var ph := 12.0 + 90.0 * t
				var lamp := base - Vector2(14 * t, ph)
				_gl(c, lamp, Vector2(16, 16) * (0.4 + t), Color(1, 0.72, 0.4, 0.8))
				c.draw_texture_rect(_glow_tex, Rect2(lamp.x - 5 * (0.5 + t), base.y, 10 * (0.5 + t), 60 * t), false, Color(1, 0.7, 0.4, 0.25))
			_gl(c, Vector2(w * 0.4, hz), Vector2(w * 0.5, 30), Color(1, 0.6, 0.35, 0.12))
			var v := Vector2(w * 0.33, h * 0.78)
			var b := _beacon()
			_gl(c, v + Vector2(0, -52), Vector2(90, 60), Color(b.r, b.g, b.b, 0.55))
			_gl(c, v + Vector2(0, 10), Vector2(150, 30), Color(b.r, b.g, b.b, 0.25))
			for dx in [-23.0, 23.0]:
				_gl(c, v + Vector2(dx, -8), Vector2(18, 12), Color(1, 0.95, 0.8, 0.9))
				c.draw_texture_rect(_glow_tex, Rect2(v.x + dx - 6, v.y, 12, 70), false, Color(1, 0.92, 0.75, 0.3))
			if motif == "crash":
				for i in 3:
					var bc := _beacon(i * 0.33)
					_gl(c, Vector2(w * (0.6 + i * 0.12), h * 0.62), Vector2(60, 40), Color(bc.r, bc.g, bc.b, 0.35))
				_gl(c, Vector2(w * 0.55, h * 0.8), Vector2(20, 14), Color(1, 0.3, 0.1, 0.8 + 0.2 * sin(_time * 20)))
		"plant":
			_gl(c, Vector2(w * 0.55, hz - 10), Vector2(w * 0.45, 70), Color(0.55, 0.95, 0.4, 0.18))
			for i in 3:
				var cx := w * (0.42 + i * 0.17)
				var ch := hz * (0.95 - i * 0.18)
				if fmod(_time + i * 0.7, 2.0) < 1.0:
					_gl(c, Vector2(cx, hz - ch - 3), Vector2(10, 10), Color(1, 0.2, 0.1, 0.9))
		"room", "office":
			_gl(c, Vector2(w * 0.12, h * 0.36), Vector2(w * 0.3, h * 0.5), Color(1, 0.72, 0.38, 0.45))
			if motif == "room" and fmod(_time, 1.2) < 0.6:
				_gl(c, Vector2(w * 0.28, h * 0.6), Vector2(40, 30), Color(1, 0.85, 0.6, 0.4))
		"lab":
			_gl(c, Vector2(w * 0.5, 0), Vector2(w * 0.6, h * 0.7), Color(0.7, 0.86, 1.0, 0.35))
		"door":
			var on := fmod(_time * 1.5, 1.0) < 0.5
			_gl(c, Vector2(w * 0.5, h * 0.12), Vector2(w * 0.3, h * 0.4), Color(1, 0.12, 0.08, 0.6 if on else 0.2))
			_gl(c, Vector2(w * 0.5, h * 0.5), Vector2(w * 0.2, h * 0.35), Color(1, 0.9, 0.75, 0.25))
