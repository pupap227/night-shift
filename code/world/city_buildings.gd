class_name CityBuildings
extends Node2D
## Buildings, trees and lamp posts, painter-sorted back to front.
## Hospital blocks use dedicated archetypes so each department reads by silhouette and light:
##   main_hall — old stucco main building, portico, hip roof, rooftop letters
##   er_annex  — bright glazed admissions with canopy, red lightbox and beacons
##   surgery   — closed white-tile block with a frosted green operating band
##   icu       — dim block with steady teal monitor glow
##   lab       — glass-block bands of cold white light
##   morgue    — the darkest object on the map
## Any building is replaced by res://art/buildings/<id>.png if that file exists.

const STYLE := {
	"panel": Color("2c3440"), "brick": Color("3b2c28"), "police": Color("2f3848"), "fire": Color("472f2a"),
	"industrial": Color("2c302e"), "house": Color("362f2a"), "shop": Color("2e353e"), "garage": Color("262b31"),
	"chimney": Color("3d302c"), "tank": Color("3a3f42"),
	"main_hall": Color("6e6452"), "er_annex": Color("5d6366"), "surgery": Color("7a8584"), "icu": Color("56616a"),
	"lab": Color("646d74"), "morgue": Color("2a2d31"), "hosp_brick": Color("4d3a32"),
}
const WIN_WARM := Color(0.96, 0.74, 0.4)
const WIN_SOFT := Color(0.85, 0.62, 0.36)
const WIN_COOL := Color(0.82, 0.92, 0.88)
const WIN_TEAL := Color(0.38, 0.78, 0.82)
const WIN_TV := Color(0.5, 0.62, 0.95)
const WIN_DARK := Color(0.06, 0.075, 0.1)
const BOUNCE := Color("4a3826")
const SKY := Color("17233a")

var model: CityModel
var highlight: Dictionary = {}     # building id -> Color (outline)
var dim := 0.0                     # 0..1, darkens non-target buildings while targeting
var dim_except: Dictionary = {}    # building ids kept bright while dimmed
var alarm := 0
var _objects: Array = []
var _time := 0.0
var _acc := 0.0
var _font: Font


func setup(m: CityModel) -> void:
	model = m
	_font = Assets.font("display")
	_objects.clear()
	for b in model.buildings:
		_objects.append({"depth": b.rect.end.x + b.rect.end.y - 0.01, "kind": "b", "ref": b})
	for t in model.trees:
		_objects.append({"depth": t.x + t.y + 0.3, "kind": "t", "ref": t})
	for l in model.lamps:
		_objects.append({"depth": l.x + l.y + 0.2, "kind": "l", "ref": l})
	_objects.sort_custom(func(a, b): return a.depth < b.depth)
	queue_redraw()


func set_highlight(h: Dictionary) -> void:
	if h != highlight:
		highlight = h
		queue_redraw()


func set_dim(v: float, keep: Dictionary) -> void:
	if not is_equal_approx(v, dim) or keep != dim_except:
		dim = v
		dim_except = keep
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_acc += delta
	if _acc > 0.12:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	if model == null:
		return
	for o in _objects:
		match o.kind:
			"b":
				_draw_building(o.ref)
				if dim > 0.0 and not dim_except.has(o.ref.id):
					draw_colored_polygon(o.ref.silhouette, Color(0.01, 0.015, 0.03, dim * 0.72))
			"t":
				_draw_tree(o.ref)
			"l":
				_draw_lamp(o.ref)


# ------------------------------------------------------------------ helpers

## Gradient face: bottom edge a→b, top edge b'→a' (vertical extrusion of h).
func _face(a: Vector2, b: Vector2, z0: float, z1: float, cb: Color, ct: Color) -> void:
	draw_polygon(PackedVector2Array([Iso.p(a, z0), Iso.p(b, z0), Iso.p(b, z1), Iso.p(a, z1)]),
		PackedColorArray([cb, cb, ct, ct]))


func _lit_face_colors(base: Color, right: bool) -> Array:
	var c := base.darkened(0.42) if right else base
	var bottom := c.lerp(BOUNCE, 0.28).lightened(0.04)
	var top := c.darkened(0.2).lerp(SKY, 0.22)
	return [bottom, top]


func _box(r: Rect2, z0: float, z1: float, base: Color, roof := true) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var l := _lit_face_colors(base, false)
	var rr := _lit_face_colors(base, true)
	_face(Vector2(x0, y1), Vector2(x1, y1), z0, z1, l[0], l[1])
	_face(Vector2(x1, y1), Vector2(x1, y0), z0, z1, rr[0], rr[1])
	if roof:
		var top := base.darkened(0.55).lerp(SKY, 0.25)
		draw_colored_polygon(Iso.quad(x0, y0, r.size.x, r.size.y, z1), top)
		draw_polyline(PackedVector2Array([Iso.pxy(x0, y1, z1), Iso.pxy(x1, y1, z1), Iso.pxy(x1, y0, z1)]), base.lightened(0.12), 1.0)


func _quad_on_left(x: float, y: float, w: float, z0: float, z1: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Iso.pxy(x, y, z0), Iso.pxy(x + w, y, z0), Iso.pxy(x + w, y, z1), Iso.pxy(x, y, z1)]), col)


func _quad_on_right(x: float, y: float, w: float, z0: float, z1: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Iso.pxy(x, y, z0), Iso.pxy(x, y - w, z0), Iso.pxy(x, y - w, z1), Iso.pxy(x, y, z1)]), col)


func _win_color(b: Dictionary, face: int, i: int, f: int, lit: float, palette: Array) -> Color:
	var hs := Iso.hash01(b.seed + face * 977, i, f)
	var bucket := int(_time / 9.0)
	var flick := Iso.hash01(b.seed, i * 31 + f, bucket + face) < 0.04
	if (hs < lit) == flick:
		return WIN_DARK
	var c: Color = palette[int(hs * 997.0) % palette.size()]
	return c.darkened(Iso.hash01(i, f, b.seed) * 0.4)


## Regular window grid on both visible faces.
func _windows(b: Dictionary, r: Rect2, floors: int, fh: float, z_base: float, per_tile: float, wz0: float, wz1: float, lit: float, palette: Array, tall := false) -> void:
	for face in 2:
		var length := r.size.x if face == 0 else r.size.y
		var cols := maxi(1, int(round(length * per_tile)))
		for f in floors:
			for i in cols:
				var col := _win_color(b, face, i, f, lit, palette)
				var u0 := (i + 0.27) / cols * length
				var u1 := (i + 0.73) / cols * length
				var za := z_base + f * fh + wz0
				var zb := z_base + f * fh + wz1
				if face == 0:
					_quad_on_left(r.position.x + u0, r.end.y, u1 - u0, za, zb, col)
					if col != WIN_DARK and tall:
						_quad_on_left(r.position.x + u0, r.end.y, u1 - u0, za, za + 1.2, col.lightened(0.25))
				else:
					_quad_on_right(r.end.x, r.end.y - u0, u1 - u0, za, zb, col.darkened(0.3) if col != WIN_DARK else col)


# ------------------------------------------------------------------ dispatch

func _draw_building(b: Dictionary) -> void:
	var tex := Assets.texture("buildings", b.id)
	if tex:
		var r: Rect2 = b.rect
		var cx := (Iso.pxy(r.position.x, r.end.y).x + Iso.pxy(r.end.x, r.position.y).x) * 0.5
		draw_texture(tex, Vector2(cx - tex.get_width() * 0.5, Iso.pxy(r.end.x, r.end.y).y - tex.get_height()))
	else:
		match b.style:
			"main_hall":
				_main_hall(b)
			"er_annex":
				_er_annex(b)
			"surgery":
				_surgery(b)
			"icu":
				_icu(b)
			"lab":
				_lab(b)
			"morgue":
				_morgue(b)
			"chimney":
				_chimney(b)
			"tank":
				_cylinder(b.rect.get_center(), 0.45, b.h, STYLE.tank)
			_:
				_generic(b)
	_outline(b)


func _outline(b: Dictionary) -> void:
	if not highlight.has(b.id):
		return
	var col: Color = highlight[b.id]
	var s: PackedVector2Array = b.silhouette.duplicate()
	s.append(s[0])
	var halo := col
	halo.a *= 0.25
	draw_polyline(s, halo, 7.0, true)
	draw_polyline(s, col, 2.0, true)


# ------------------------------------------------------------------ hospital archetypes

func _main_hall(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var base: Color = STYLE.main_hall
	var fh := 13.0
	var floors: int = b.floors
	var h := floors * fh + 6.0
	_box(r, 0, h, base, false)
	# Plinth and cornice bands
	_quad_on_left(r.position.x, r.end.y, r.size.x, 0, 6, base.darkened(0.45))
	_quad_on_right(r.end.x, r.end.y, r.size.y, 0, 6, base.darkened(0.65))
	_quad_on_left(r.position.x, r.end.y, r.size.x, h - 4, h, base.lightened(0.18))
	_quad_on_right(r.end.x, r.end.y, r.size.y, h - 4, h, base.darkened(0.25))
	_windows(b, r, floors, fh, 6.0, 2.2, 2.5, 10.5, b.lit, [WIN_WARM, WIN_SOFT, WIN_WARM, WIN_COOL], true)
	# Central risalit with portico on the front (left) face.
	var cx := r.position.x + r.size.x * 0.5
	var pw := 1.7
	var px0 := cx - pw * 0.5
	var y1 := r.end.y + 0.35
	_box(Rect2(px0, r.end.y - 0.1, pw, 0.45), 0, h + 4, base.lightened(0.08), true)
	# Pediment
	var ped := PackedVector2Array([Iso.pxy(px0, y1, h + 4), Iso.pxy(px0 + pw, y1, h + 4), Iso.pxy(cx, y1, h + 15)])
	draw_colored_polygon(ped, base.lightened(0.12))
	draw_polyline(PackedVector2Array([ped[0], ped[2], ped[1]]), base.lightened(0.3), 1.0)
	# Columns + lit doorway + steps
	draw_colored_polygon(PackedVector2Array([Iso.pxy(px0 + 0.45, y1, 0), Iso.pxy(px0 + pw - 0.45, y1, 0), Iso.pxy(px0 + pw - 0.45, y1, 14), Iso.pxy(px0 + 0.45, y1, 14)]), Color(1.0, 0.86, 0.6, 0.95))
	for k in 4:
		var x := px0 + 0.12 + k * (pw - 0.24) / 3.0
		draw_line(Iso.pxy(x, y1 + 0.02, 2), Iso.pxy(x, y1 + 0.02, h - 6), base.lightened(0.35), 2.2)
	for k in 3:
		var sy := y1 + 0.12 + k * 0.12
		draw_line(Iso.pxy(px0 - 0.1 - k * 0.08, sy, 2 - k * 0.7), Iso.pxy(px0 + pw + 0.1 + k * 0.08, sy, 2 - k * 0.7), base.lightened(0.2 - k * 0.05), 1.6)
	# Hip roof (old green-grey metal)
	var rise := 16.0
	var ins := minf(r.size.x, r.size.y) * 0.35
	var ym := r.position.y + r.size.y * 0.5
	var roof := Color("2e3a37")
	draw_colored_polygon(PackedVector2Array([Iso.pxy(r.position.x, r.position.y, h), Iso.pxy(r.end.x, r.position.y, h), Iso.pxy(r.end.x - ins, ym, h + rise), Iso.pxy(r.position.x + ins, ym, h + rise)]), roof.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([Iso.pxy(r.position.x, r.position.y, h), Iso.pxy(r.position.x, r.end.y, h), Iso.pxy(r.position.x + ins, ym, h + rise)]), roof.darkened(0.15))
	draw_polygon(PackedVector2Array([Iso.pxy(r.position.x, r.end.y, h), Iso.pxy(r.end.x, r.end.y, h), Iso.pxy(r.end.x - ins, ym, h + rise), Iso.pxy(r.position.x + ins, ym, h + rise)]),
		PackedColorArray([roof, roof, roof.lightened(0.12), roof.lightened(0.12)]))
	draw_colored_polygon(PackedVector2Array([Iso.pxy(r.end.x, r.end.y, h), Iso.pxy(r.end.x, r.position.y, h), Iso.pxy(r.end.x - ins, ym, h + rise)]), roof.darkened(0.45))
	draw_line(Iso.pxy(r.position.x + ins, ym, h + rise), Iso.pxy(r.end.x - ins, ym, h + rise), Color(0.6, 0.7, 0.8, 0.35), 1.2)
	# Rooftop letters on a frame — the landmark.
	var lx0 := r.position.x + 0.4
	var lz := h + 7.0
	var p0 := Iso.pxy(lx0, r.end.y - 0.2, lz)
	var p1 := Iso.pxy(r.end.x - 0.4, r.end.y - 0.2, lz)
	draw_line(Iso.pxy(lx0, r.end.y - 0.2, h), p0, Color("1a1e22"), 1.5)
	draw_line(Iso.pxy(r.end.x - 0.4, r.end.y - 0.2, h), p1, Color("1a1e22"), 1.5)
	var dir := (p1 - p0).normalized()
	var m := Transform2D(dir, Vector2(0, 1), p0)
	var flicker := 1.0 if fmod(_time * 0.7 + 3.0, 11.0) > 0.25 else 0.35
	var txt := "БОЛЬНИЦА"
	var fs := 15
	var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var span := p0.distance_to(p1)
	draw_set_transform_matrix(m)
	draw_string(_font, Vector2((span - tw) * 0.5, -2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.86, 0.62, 0.95 * flicker))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _er_annex(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var base: Color = STYLE.er_annex
	var fh := 12.0
	var h := 2 * fh + 3.0
	_box(r, 0, h, base)
	# Ground floor: long glazed front, lit warm white.
	var glass := Color(0.98, 0.93, 0.8)
	_quad_on_left(r.position.x + 0.2, r.end.y, r.size.x - 0.4, 1.5, fh - 1.5, glass.darkened(0.08))
	for k in int(r.size.x * 2):
		var x := r.position.x + 0.2 + k * 0.5
		draw_line(Iso.pxy(x, r.end.y, 1.5), Iso.pxy(x, r.end.y, fh - 1.5), Color(0.3, 0.32, 0.3, 0.6), 1.0)
	_quad_on_right(r.end.x, r.end.y - 0.2, r.size.y - 0.4, 1.5, fh - 1.5, glass.darkened(0.45))
	_windows(b, Rect2(r.position.x, r.position.y, r.size.x, r.size.y), 1, fh, fh, 2.0, 3.0, 9.0, 0.85, [WIN_COOL, WIN_WARM])
	# Canopy on posts over the ambulance bay.
	var cx0 := r.position.x - 0.3
	var cw := 3.4
	var cy := r.end.y
	var cd := 1.3
	for q in [Vector2(cx0 + 0.1, cy + cd - 0.1), Vector2(cx0 + cw - 0.1, cy + cd - 0.1)]:
		draw_line(Iso.p(q, 0), Iso.p(q, 14), Color("3d4348"), 2.0)
	draw_colored_polygon(Iso.quad(cx0, cy, cw, cd, 14), Color("555c62"))
	_quad_on_left(cx0, cy + cd, cw, 14, 17, Color("6a7177"))
	_quad_on_right(cx0 + cw, cy + cd, cd, 14, 17, Color("40464b"))
	# Red lightbox "ПРИЁМНОЕ" on the canopy fascia.
	var pulse := 0.8 + 0.2 * sin(_time * 2.2)
	_quad_on_left(cx0 + 0.3, cy + cd + 0.01, cw - 0.6, 14.3, 16.7, Color(0.75, 0.08, 0.08, pulse))
	var p0 := Iso.pxy(cx0 + 0.45, cy + cd + 0.02, 14.6)
	var p1 := Iso.pxy(cx0 + cw - 0.45, cy + cd + 0.02, 14.6)
	draw_set_transform_matrix(Transform2D((p1 - p0).normalized(), Vector2(0, 1), p0))
	draw_string(_font, Vector2(3, -0.6), "ПРИЁМНОЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.92, 0.88, pulse))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Beacons on canopy corners
	var on := fmod(_time * 1.6, 1.0) < 0.5
	for q in [Vector2(cx0 + 0.1, cy + cd), Vector2(cx0 + cw - 0.1, cy + cd)]:
		draw_circle(Iso.p(q, 18.5), 2.2, Color(1, 0.18, 0.12, 1.0 if on else 0.25))
	# Rooftop red cross lightbox.
	var c := Iso.pxy(r.position.x + r.size.x * 0.65, r.position.y + r.size.y * 0.5, h + 12)
	draw_line(c + Vector2(-6, 10), c + Vector2(-6, 2), Color("1d2125"), 1.5)
	draw_line(c + Vector2(6, 10), c + Vector2(6, 2), Color("1d2125"), 1.5)
	draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), Color(0.95, 0.95, 0.92, 0.95))
	draw_rect(Rect2(c - Vector2(2.6, 7), Vector2(5.2, 14)), Color(0.85, 0.08, 0.08, pulse))
	draw_rect(Rect2(c - Vector2(7, 2.6), Vector2(14, 5.2)), Color(0.85, 0.08, 0.08, pulse))


func _surgery(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var base: Color = STYLE.surgery
	var fh := 12.0
	var h := 3 * fh + 4.0
	_box(r, 0, h, base)
	# Tile grid
	var grid := Color(0, 0, 0, 0.12)
	var x := r.position.x + 0.5
	while x < r.end.x:
		draw_line(Iso.pxy(x, r.end.y, 0), Iso.pxy(x, r.end.y, h), grid, 1.0)
		x += 0.5
	for f in 3:
		draw_line(Iso.pxy(r.position.x, r.end.y, f * fh), Iso.pxy(r.end.x, r.end.y, f * fh), grid, 1.0)
	# Ground floor: a few small windows; 2nd floor: frosted operating band (cold green).
	_windows(b, r, 1, fh, 0, 1.0, 3.0, 8.0, 0.5, [WIN_COOL])
	var band := Color(0.55, 0.95, 0.8, 0.75 + 0.15 * sin(_time * 0.8))
	_quad_on_left(r.position.x + 0.3, r.end.y, r.size.x - 0.6, fh + 2, 2 * fh - 2, band)
	_quad_on_right(r.end.x, r.end.y - 0.3, r.size.y - 0.6, fh + 2, 2 * fh - 2, band.darkened(0.45))
	for k in int(r.size.x * 3):
		var xx := r.position.x + 0.3 + k / 3.0
		draw_line(Iso.pxy(xx, r.end.y, fh + 2), Iso.pxy(xx, r.end.y, 2 * fh - 2), Color(1, 1, 1, 0.18), 1.0)
	_windows(b, r, 1, fh, 2 * fh, 1.0, 3.0, 8.0, 0.25, [WIN_COOL])
	# Rooftop plant: ducts and vent boxes.
	_mini_box(r.position.x + 0.4, r.position.y + 0.5, 1.2, 0.8, h, 7.0, Color("5f6767"))
	_mini_box(r.position.x + 2.0, r.position.y + 0.4, 0.6, 0.6, h, 10.0, Color("596060"))
	draw_line(Iso.pxy(r.position.x + 1.6, r.position.y + 0.9, h + 5), Iso.pxy(r.position.x + 2.0, r.position.y + 0.7, h + 5), Color("6c7474"), 3.0)


func _icu(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var base: Color = STYLE.icu
	var fh := 12.0
	var h := 3 * fh + 3.0
	_box(r, 0, h, base)
	_windows(b, r, 3, fh, 0, 2.0, 3.0, 9.0, 0.45, [WIN_TEAL, WIN_TEAL, Color(0.3, 0.6, 0.75)])
	var red := Color(0.78, 0.2, 0.22, 0.85)
	_quad_on_left(r.position.x, r.end.y, r.size.x, h - 4, h - 1.5, red)
	_quad_on_right(r.end.x, r.end.y, r.size.y, h - 4, h - 1.5, red.darkened(0.4))
	var on := fmod(_time, 2.4) < 0.12
	draw_circle(Iso.pxy(r.end.x - 0.2, r.end.y - 0.2, h + 3), 1.8, Color(1, 0.2, 0.15, 1.0 if on else 0.3))


func _lab(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var base: Color = STYLE.lab
	var fh := 12.0
	var h := 2 * fh + 3.0
	_box(r, 0, h, base)
	for f in 2:
		var z0 := f * fh + 3.0
		for face in 2:
			var length := r.size.x if face == 0 else r.size.y
			var n := int(length * 6)
			for i in n:
				for j in 3:
					var lit := Iso.hash01(i, j + f * 7, b.seed + face) < 0.75
					var c := Color(0.86, 0.94, 1.0, 0.9) if lit else Color(0.2, 0.25, 0.3)
					var u := 0.1 + i * (length - 0.2) / n
					var w := (length - 0.2) / n * 0.8
					if face == 0:
						_quad_on_left(r.position.x + u, r.end.y, w, z0 + j * 2.4, z0 + j * 2.4 + 1.8, c)
					else:
						_quad_on_right(r.end.x, r.end.y - u, w, z0 + j * 2.4, z0 + j * 2.4 + 1.8, c.darkened(0.4))


func _morgue(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var base: Color = STYLE.morgue
	var h := 12.0
	_box(r, 0, h, base)
	# Heavy metal door, one weak lamp.
	_quad_on_left(r.position.x + 0.5, r.end.y, 0.55, 0, 8, Color("17191c"))
	var lamp := Iso.pxy(r.position.x + 0.78, r.end.y, 10)
	draw_circle(lamp, 1.6, Color(1.0, 0.8, 0.5, 0.7 + 0.3 * float(fmod(_time * 3.1, 7.0) > 0.2)))
	_mini_box(r.end.x - 0.6, r.position.y + 0.3, 0.3, 0.3, h, 9.0, Color("2a2a2c"))


# ------------------------------------------------------------------ city

func _generic(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var base: Color = STYLE.get(b.style, STYLE.panel)
	var h: float = b.h
	_box(r, 0, h, base, b.roof != "pitched")
	if b.style == "panel":
		var x := r.position.x + 1.0
		while x < r.end.x - 0.01:
			draw_line(Iso.pxy(x, r.end.y), Iso.pxy(x, r.end.y, h), Color(0, 0, 0, 0.18), 1.0)
			x += 1.0
	if b.style == "police":
		_quad_on_left(r.position.x, r.end.y, r.size.x, 9, 11, Color(0.25, 0.42, 0.8, 0.8))
		var on := fmod(_time * 2.0, 1.0) < 0.5
		draw_circle(Iso.pxy(r.position.x + 0.4, r.end.y, h + 3), 2.0, Color(0.3, 0.5, 1.0, 1.0 if on else 0.3))
	if b.style == "fire":
		for k in 3:
			var a := r.position.x + 0.3 + k * 1.2
			_quad_on_left(a, r.end.y, 0.9, 0, 10, Color(0.62, 0.17, 0.12) if k != 1 else Color(0.95, 0.78, 0.5, 0.9))
	if b.style == "garage":
		for k in int(r.size.x):
			_quad_on_left(r.position.x + 0.1 + k, r.end.y, 0.8, 0, 7, base.darkened(0.3))
	if b.style not in ["garage", "tank", "chimney"]:
		var per := 2.0 if b.style != "industrial" else 1.0
		var floors: int = b.floors
		var top_off := 0.0
		_windows(b, r, floors, Iso.FLOOR, top_off, per, 3.0, 8.5, b.lit, [WIN_WARM, WIN_SOFT, WIN_WARM, WIN_WARM, WIN_TV])
	if b.roof == "pitched":
		_pitched_roof(b, base)
	elif b.roof == "saw":
		_saw_roof(b, base)
	match b.sign:
		"shop":
			_quad_on_left(r.position.x + 0.1, r.end.y, r.size.x - 0.2, 8, 10.5, Color(0.4, 0.85, 0.8, 0.85))
		"gas":
			_mini_box(r.position.x - 0.2, r.end.y + 0.3, 3.4, 1.2, 14, 2.0, Color("5a5f66"))
			draw_line(Iso.pxy(r.position.x - 0.2, r.end.y + 1.5, 14), Iso.pxy(r.end.x + 0.2, r.end.y + 1.5, 14), Color(0.95, 0.95, 0.85, 0.9), 1.5)


func _pitched_roof(b: Dictionary, base: Color) -> void:
	var r: Rect2 = b.rect
	var h: float = b.h
	var rise := 9.0
	var ym := r.position.y + r.size.y * 0.5
	var roof := Color("26232a")
	draw_colored_polygon(PackedVector2Array([Iso.pxy(r.position.x, r.position.y, h), Iso.pxy(r.end.x, r.position.y, h), Iso.pxy(r.end.x, ym, h + rise), Iso.pxy(r.position.x, ym, h + rise)]), roof.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Iso.pxy(r.end.x, r.position.y, h), Iso.pxy(r.end.x, r.end.y, h), Iso.pxy(r.end.x, ym, h + rise)]), base.darkened(0.45))
	draw_colored_polygon(PackedVector2Array([Iso.pxy(r.position.x, r.end.y, h), Iso.pxy(r.end.x, r.end.y, h), Iso.pxy(r.end.x, ym, h + rise), Iso.pxy(r.position.x, ym, h + rise)]), roof)
	draw_line(Iso.pxy(r.position.x, ym, h + rise), Iso.pxy(r.end.x, ym, h + rise), Color(0.55, 0.6, 0.7, 0.25), 1.0)
	_mini_box(r.position.x + 0.4, ym - 0.2, 0.25, 0.25, h + rise - 3, 7.0, Color("3a3030"))


func _saw_roof(b: Dictionary, base: Color) -> void:
	var r: Rect2 = b.rect
	var h: float = b.h
	for k in int(r.size.y):
		var ya := r.position.y + k
		draw_colored_polygon(PackedVector2Array([Iso.pxy(r.position.x, ya + 1.0, h), Iso.pxy(r.end.x, ya + 1.0, h), Iso.pxy(r.end.x, ya + 0.35, h + 7), Iso.pxy(r.position.x, ya + 0.35, h + 7)]), base.darkened(0.35))
		draw_colored_polygon(PackedVector2Array([Iso.pxy(r.position.x, ya, h), Iso.pxy(r.end.x, ya, h), Iso.pxy(r.end.x, ya + 0.35, h + 7), Iso.pxy(r.position.x, ya + 0.35, h + 7)]), Color(0.85, 0.6, 0.3, 0.4 if k % 2 == 0 else 0.15))


func _mini_box(x: float, y: float, w: float, d: float, z: float, hh: float, c: Color) -> void:
	_face(Vector2(x, y + d), Vector2(x + w, y + d), z, z + hh, c, c.darkened(0.1))
	_face(Vector2(x + w, y + d), Vector2(x + w, y), z, z + hh, c.darkened(0.4), c.darkened(0.45))
	draw_colored_polygon(Iso.quad(x, y, w, d, z + hh), c.lightened(0.06))


func _chimney(b: Dictionary) -> void:
	var c: Vector2 = b.rect.get_center()
	var h: float = b.h
	var bands := int(h / 22.0)
	for k in bands + 1:
		var z0 := k * 22.0
		var col := Color("5a3530") if k % 2 == 0 else Color("6d6661")
		_cylinder_part(c, 0.32 - k * 0.012, 0.32 - (k + 1) * 0.012, z0, minf(h, z0 + 22.0), col)
	var blink := fmod(_time, 2.0) < 1.0
	draw_circle(Iso.p(c, h + 2), 2.2, Color(1, 0.15, 0.1, 0.95 if blink else 0.2))


func _cylinder(center: Vector2, rad: float, h: float, col: Color) -> void:
	_cylinder_part(center, rad, rad, 0.0, h, col)
	var top := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		top.append(Iso.p(center + Vector2(cos(a), sin(a)) * rad, h))
	draw_colored_polygon(top, col.darkened(0.25))


func _cylinder_part(center: Vector2, r0: float, r1: float, z0: float, z1: float, col: Color) -> void:
	var c0 := Iso.p(center, z0)
	var c1 := Iso.p(center, z1)
	var rx0 := r0 * Iso.TW * 0.7071
	var rx1 := r1 * Iso.TW * 0.7071
	var pts := PackedVector2Array()
	var n := 12
	for i in n + 1:
		pts.append(c0 + Vector2(cos(PI * i / n) * rx0, sin(PI * i / n) * rx0 * 0.5))
	for i in range(n, -1, -1):
		pts.append(c1 + Vector2(cos(PI * i / n) * rx1, sin(PI * i / n) * rx1 * 0.5))
	draw_colored_polygon(pts, col.darkened(0.25))
	var half := PackedVector2Array()
	for i in range(n / 2, n + 1):
		half.append(c0 + Vector2(cos(PI * i / n) * rx0, sin(PI * i / n) * rx0 * 0.5))
	for i in range(n, n / 2 - 1, -1):
		half.append(c1 + Vector2(cos(PI * i / n) * rx1, sin(PI * i / n) * rx1 * 0.5))
	draw_colored_polygon(half, col)


func _draw_tree(t: Vector3) -> void:
	var p := Iso.p(Vector2(t.x, t.y))
	var s := t.z
	var conifer := Iso.hash01(int(t.x * 13), int(t.y * 7)) < 0.55
	draw_line(p, p - Vector2(0, 6 * s), Color("17120f"), 1.5)
	if conifer:
		for k in 3:
			var y := p.y - 5 * s - k * 6 * s
			var w := (9.0 - k * 2.2) * s
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - w, y), Vector2(p.x + w, y), Vector2(p.x, y - 10 * s)]), Color("0b1514").lightened(k * 0.02))
			draw_line(Vector2(p.x - w, y), Vector2(p.x, y - 10 * s), Color(0.45, 0.55, 0.7, 0.1), 1.0)
	else:
		var c := p - Vector2(0, 13 * s)
		for k in 4:
			var o := Vector2((Iso.hash01(k, int(t.x * 10)) - 0.5) * 9 * s, (Iso.hash01(k, int(t.y * 10)) - 0.5) * 6 * s)
			draw_circle(c + o, 6.5 * s, Color("0f1817").lightened(k * 0.015))


func _draw_lamp(l: Vector2) -> void:
	var p := Iso.p(l)
	draw_line(p, p - Vector2(0, 24), Color("272c33"), 1.4)
	draw_line(p - Vector2(0, 24), p - Vector2(-5, 25), Color("272c33"), 1.2)
	draw_circle(p - Vector2(-5, 24), 1.8, Color(1.0, 0.82, 0.55))
