class_name PaintedMap
extends Node2D
## A painted (pre-rendered) city map with the game's interactive layer on top:
## department polygons for picking and highlighting, light pulses, ambulance beacons,
## highway traffic, staff figures walking between department doors, and the "targeting"
## dim where target buildings are cut out of the darkness and stay lit.
## Data: res://data/map_painted.json (coordinates in source-art pixels).

var cfg: Dictionary
var tex: Texture2D
var k := 2.0                         # source px -> world px
var depts: Dictionary = {}           # id -> {poly: PackedVector2Array(world), pin, door, uv}
var pois: Dictionary = {}
var dim := 0.0
var highlight: Dictionary = {}       # dept id -> Color
var rings: Dictionary = {}           # dept id -> Color
var hover_dept := ""
var ambulances: Dictionary = {}      # case uid -> {start, end}
var _lights: LightLayer
var _time := 0.0
var _route: PackedVector2Array


func load_cfg(d: Dictionary) -> bool:
	cfg = d
	tex = Assets.texture("city", d.get("image", "map_night"))
	if tex == null:
		return false
	var src: Array = d.get("source_size", [1672, 567])
	k = float(tex.get_width()) / float(src[0])
	for id in d.get("departments", {}):
		var e: Dictionary = d.departments[id]
		depts[id] = {"poly": _poly(e.poly), "pin": _pt(e.pin), "door": _pt(e.door)}
	for id in d.get("pois", {}):
		var e2: Dictionary = d.pois[id]
		pois[id] = {"poly": _poly(e2.poly), "pin": _pt(e2.pin)}
	_route = _poly(d.get("routes", {}).get("default", []))
	_lights = LightLayer.new()
	_lights.owner_map = self
	add_child(_lights)
	Game.ambulance_dispatched.connect(func(uid, _r, s, e): ambulances[uid] = {"start": s, "end": e})
	return true


func _pt(a: Array) -> Vector2:
	var off: Array = cfg.get("offset", [0, 0])
	return (Vector2(a[0], a[1]) + Vector2(off[0], off[1])) * k


func _poly(a: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for q in a:
		p.append(_pt(q))
	return p


func size() -> Vector2:
	return Vector2(tex.get_width(), tex.get_height())


func focus_world() -> Vector2:
	return _pt(cfg.get("focus", [820, 280]))


func zoom_for(mode: String) -> float:
	return float(cfg.get("zoom", {}).get(mode, 0.5))


func pin_world(dept_id: String) -> Vector2:
	if depts.has(dept_id):
		return depts[dept_id].pin
	if pois.has(dept_id):
		return pois[dept_id].pin
	return Vector2(-99999, -99999)


func center_of(dept_id: String) -> Vector2:
	if not depts.has(dept_id):
		return focus_world()
	var p: PackedVector2Array = depts[dept_id].poly
	var c := Vector2.ZERO
	for q in p:
		c += q
	return c / maxf(1.0, p.size())


func target_at(w: Vector2) -> Dictionary:
	for id in depts:
		if Geometry2D.is_point_in_polygon(w, depts[id].poly):
			return {"kind": "dept", "id": id}
	for id in pois:
		if Geometry2D.is_point_in_polygon(w, pois[id].poly):
			return {"kind": "poi", "id": id}
	return {}


## Where a staff member's figure stands / walks, in world coords.
func staff_world(s: StaffMember) -> Vector2:
	var stand := _door_of(s.location) + _offset(s)
	if s.state != StaffMember.State.MOVING or s.path.size() < 2:
		return stand
	var from_dept := _nearest_dept_by_tile(s.path[0])
	var a := _door_of(from_dept)
	var hub := _pt(cfg.get("yard_hub", [800, 340]))
	var t := clampf(inverse_lerp(s.move_start, s.move_end, Game.minutes), 0.0, 1.0)
	if t < 0.5:
		return a.lerp(hub, t * 2.0)
	return hub.lerp(stand, (t - 0.5) * 2.0)


func _door_of(dept_id: String) -> Vector2:
	if depts.has(dept_id):
		return depts[dept_id].door
	return _pt(cfg.get("yard_hub", [800, 340]))


func _offset(s: StaffMember) -> Vector2:
	var i := 0
	for o: StaffMember in Game.staff.values():
		if o == s:
			break
		if o.location == s.location:
			i += 1
	return Vector2((i % 4 - 1.5) * 14.0, (i / 4) * 12.0)


func _nearest_dept_by_tile(tile: Vector2) -> String:
	var best := "staffroom"
	var bd := INF
	for d: DepartmentData in Game.db.departments.values():
		var dd := d.entrance.distance_to(tile)
		if dd < bd:
			bd = dd
			best = d.id
	return best


func _route_pos(t: float) -> Vector2:
	if _route.size() < 2:
		return Vector2.ZERO
	var total := 0.0
	for i in range(1, _route.size()):
		total += _route[i - 1].distance_to(_route[i])
	var d := t * total
	for i in range(1, _route.size()):
		var seg := _route[i - 1].distance_to(_route[i])
		if d <= seg:
			return _route[i - 1].lerp(_route[i], d / maxf(0.001, seg))
		d -= seg
	return _route[_route.size() - 1]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _uv(poly: PackedVector2Array) -> PackedVector2Array:
	var s := size()
	var uv := PackedVector2Array()
	for p in poly:
		uv.append(Vector2(p.x / s.x, p.y / s.y))
	return uv


func _draw() -> void:
	if tex == null:
		return
	draw_texture(tex, Vector2.ZERO)
	# Targeting: darken the city, then paint the target buildings back in, lit.
	if dim > 0.001:
		draw_rect(Rect2(Vector2(-4000, -4000), size() + Vector2(8000, 8000)), Color(0.0, 0.01, 0.03, dim * 0.72))
		for id in highlight:
			if depts.has(id):
				var poly: PackedVector2Array = depts[id].poly
				var cols := PackedColorArray()
				cols.resize(poly.size())
				cols.fill(Color(1.08, 1.08, 1.12, 1) if id == hover_dept else Color.WHITE)
				draw_polygon(poly, cols, _uv(poly), tex)
	for id in highlight:
		if not depts.has(id):
			continue
		var poly2: PackedVector2Array = depts[id].poly.duplicate()
		poly2.append(poly2[0])
		var col: Color = highlight[id]
		var halo := col
		halo.a *= 0.25
		draw_polyline(poly2, halo, 9.0, true)
		draw_polyline(poly2, col, 2.5 if id != hover_dept else 4.0, true)
	# Help-needed / verdict rings at department doors.
	for id in rings:
		if not depts.has(id):
			continue
		var c: Vector2 = depts[id].door
		var col2: Color = rings[id]
		var pulse := 1.0 + 0.12 * sin(_time * 5.0)
		var r := (34.0 if id == hover_dept else 24.0) * pulse
		var fill := col2
		fill.a *= 0.2
		draw_colored_polygon(_ellipse(c, r), fill)
		var e := _ellipse(c, r)
		e.append(e[0])
		draw_polyline(e, col2, 2.0, true)
	# Staff figures.
	for s: StaffMember in Game.staff.values():
		_figure(s, staff_world(s))


func _ellipse(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	return pts


func _figure(s: StaffMember, w: Vector2) -> void:
	var moving := s.state == StaffMember.State.MOVING
	var bob := sin(_time * 10.0) * 1.0 if moving else 0.0
	var sel := Game.selected_staff_id == s.id or Game.dragging_staff_id == s.id
	var body: Color = {"doctor": Color("e6eaee"), "nurse": Color("bcd6e2"), "orderly": Color("8494a8"), "security": Color("36425a")}.get(s.data.category, Color.WHITE)
	if s.is_locked():
		body = body.darkened(0.5)
	if sel:
		draw_arc(w, 13.0 + 1.5 * sin(_time * 6.0), 0, TAU, 24, Color(1, 1, 1, 0.9), 2.0, true)
	draw_colored_polygon(_ellipse(w, 9.0), Color(s.data.accent, 0.35))
	draw_line(w + Vector2(-2.5, 0), w + Vector2(-2.5, -8 - bob), Color("161a20"), 2.6)
	draw_line(w + Vector2(2.5, 0), w + Vector2(2.5, -8 + bob), Color("161a20"), 2.6)
	draw_colored_polygon(PackedVector2Array([w + Vector2(-6, -7), w + Vector2(6, -7), w + Vector2(5, -20 + bob), w + Vector2(-5, -20 + bob)]), body)
	draw_circle(w - Vector2(0, 24 - bob), 4.2, Color(0.85, 0.7, 0.6))


# ------------------------------------------------------------------ additive lights

class LightLayer extends Node2D:
	var owner_map: PaintedMap
	var _glow: Texture2D
	var _t := 0.0
	var _acc := 0.0

	func _ready() -> void:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		_glow = CityGlow.radial_texture()

	func _process(delta: float) -> void:
		_t += delta
		_acc += delta
		if _acc > (1.0 / 20.0 if Screen.low_power else 1.0 / 40.0):
			_acc = 0.0
			queue_redraw()

	func _g(at: Vector2, r: float, col: Color, squash := 0.6) -> void:
		draw_texture_rect(_glow, Rect2(at - Vector2(r, r * squash), Vector2(r * 2, r * 2 * squash)), false, col)

	func _beacon(phase: float) -> Color:
		return Color(0.3, 0.5, 1.0) if fmod(_t * 2.4 + phase, 1.0) < 0.5 else Color(1.0, 0.18, 0.12)

	func _draw() -> void:
		var m := owner_map
		var k := m.k
		var alarm_k := 1.0 + 0.5 * Game.alarm_level
		for l in m.cfg.get("lights", []):
			var p := m._pt(l.pos)
			var r: float = float(l.get("r", 30)) * k
			var a: float = l.get("a", 0.3)
			var col: Color
			if l.color == "beacon":
				col = _beacon(float(l.get("phase", 0.0)))
			else:
				col = Color(l.color)
			if l.has("pulse"):
				a *= 1.0 + float(l.get("amp", 0.2)) * sin(_t * float(l.pulse))
			if l.get("flicker", false) and fmod(_t * 3.1, 7.0) < 0.25:
				a *= 0.2
			if String(l.color).begins_with("#ff2a"):
				a *= alarm_k
			col.a = clampf(a, 0.0, 1.0)
			_g(p, r, col)
		# Highway traffic: head- and tail-lights streaming in both directions.
		for tr in m.cfg.get("traffic", []):
			var a0 := m._pt(tr.from)
			var b0 := m._pt(tr.to)
			var n: int = tr.get("count", 4)
			var col2 := Color(tr.color)
			for i in n:
				var t := fmod(_t * float(tr.speed) + float(i) / n, 1.0)
				var p2 := a0.lerp(b0, t)
				_g(p2, 7.0 * k, Color(col2, 0.9), 0.7)
				_g(p2, 22.0 * k, Color(col2, 0.18), 0.5)
		# Ambulances en route: a pair of flashing beacons travelling along the road to admissions.
		for uid in m.ambulances.keys():
			var am: Dictionary = m.ambulances[uid]
			if Game.minutes > am.end + 1.0:
				m.ambulances.erase(uid)
				continue
			var t2 := clampf(inverse_lerp(am.start, am.end, Game.minutes), 0.0, 1.0)
			var p3 := m._route_pos(t2)
			var bc := _beacon(0.0)
			_g(p3, 34.0 * k, Color(bc, 0.6))
			_g(p3 + Vector2(10, 4), 10.0 * k, Color(1, 0.95, 0.85, 0.9), 0.6)
