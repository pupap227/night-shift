class_name CityActors
extends Node2D
## Moving things at street level: traffic, ambulances, pedestrians and staff tokens.
## Ambient life runs on real time scaled by game speed; story actors follow game minutes.

const CAR_COLORS := [Color("5b2b2b"), Color("8a8170"), Color("2d3d35"), Color("575d66"), Color("c9c2b0"),
	Color("3a3550"), Color("6a4a2a"), Color("2a3a4a")]
const CATEGORY_COLORS := {
	"doctor": Color("dfe4e8"), "nurse": Color("b9d4e0"), "orderly": Color("7f8fa3"), "security": Color("2f3a4c"),
}

var model: CityModel
var cars: Array = []
var peds: Array = []
var ambulances: Dictionary = {}   # case uid -> {route, start, end}
var lights: Array = []            # filled each frame for CityGlow: [pos(world), radius, color]
var hover_staff := ""
var _time := 0.0


func setup(m: CityModel) -> void:
	model = m
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for li in model.lanes.size():
		var lane: Dictionary = model.lanes[li]
		var a := Vector2(lane.points[0][0], lane.points[0][1])
		var b := Vector2(lane.points[1][0], lane.points[1][1])
		var length := a.distance_to(b)
		var n: int = lane.get("count", 2)
		for k in n:
			var truck := rng.randf() < float(lane.get("trucks", 0.0))
			cars.append({
				"lane": li, "a": a, "b": b, "len": length, "t": length * (k + rng.randf() * 0.5) / n,
				"speed": float(lane.speed) * rng.randf_range(0.9, 1.05), "color": CAR_COLORS[rng.randi() % CAR_COLORS.size()],
				"truck": truck, "wait": 0.0,
			})
	for wi in model.walkways.size():
		var w: Array = model.walkways[wi]
		var a2 := Vector2(w[0][0], w[0][1])
		var b2 := Vector2(w[1][0], w[1][1])
		for k in 2:
			peds.append({"a": a2, "b": b2, "t": rng.randf(), "dir": 1.0 if rng.randf() < 0.5 else -1.0,
				"speed": rng.randf_range(0.18, 0.32) / a2.distance_to(b2), "umbrella": rng.randf() < 0.45,
				"coat": Color(rng.randf_range(0.12, 0.3), rng.randf_range(0.12, 0.25), rng.randf_range(0.14, 0.3))})
	Game.ambulance_dispatched.connect(_on_ambulance)


func _on_ambulance(uid: int, route_id: String, start_min: float, end_min: float) -> void:
	if model.routes.has(route_id):
		ambulances[uid] = {"route": model.routes[route_id], "start": start_min, "end": end_min}


func ambient_speed() -> float:
	if not Game.is_time_flowing():
		return 0.0
	return 1.0 + (Game.speed - 1) * 0.6


func _process(delta: float) -> void:
	var k := ambient_speed()
	_time += delta * k
	for c in cars:
		c.t += c.speed * delta * k
		if c.t > c.len:
			c.t = 0.0
	for p in peds:
		p.t += p.speed * p.dir * delta * k
		if p.t > 1.0 or p.t < 0.0:
			p.dir *= -1.0
			p.t = clampf(p.t, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	lights.clear()
	# Painter order inside the actor layer: sort everything by depth (x + y).
	var items: Array = []
	for c in cars:
		var pos: Vector2 = c.a + (c.b - c.a).normalized() * c.t
		items.append({"d": pos.x + pos.y, "k": "car", "c": c, "p": pos})
	for p in peds:
		var pp: Vector2 = p.a.lerp(p.b, p.t)
		items.append({"d": pp.x + pp.y, "k": "ped", "c": p, "p": pp})
	for pa in model.parked_cars:
		items.append({"d": pa.x + pa.y, "k": "parked", "p": pa})
	for i in model.parked_ambulances.size():
		items.append({"d": model.parked_ambulances[i].x + model.parked_ambulances[i].y, "k": "parked_amb", "p": model.parked_ambulances[i]})
	for uid in ambulances.keys():
		var a: Dictionary = ambulances[uid]
		if Game.minutes > a.end + 10.0:
			ambulances.erase(uid)
			continue
		var st := _route_pos(a.route, clampf(inverse_lerp(a.start, a.end, Game.minutes), 0.0, 1.0))
		items.append({"d": st.pos.x + st.pos.y, "k": "amb", "p": st.pos, "dir": st.dir, "moving": Game.minutes < a.end})
	for s: StaffMember in Game.staff.values():
		var sp := s.position_at(Game.minutes)
		items.append({"d": sp.x + sp.y, "k": "staff", "s": s, "p": sp})
	items.sort_custom(func(x, y): return x.d < y.d)
	for it in items:
		match it.k:
			"car":
				var c: Dictionary = it.c
				var dir: Vector2 = (c.b - c.a).normalized()
				if c.truck:
					_vehicle(it.p, dir, 1.7, 0.42, 11.0, Color("4a4d52"), true, false)
				else:
					_vehicle(it.p, dir, 0.85, 0.38, 6.0, c.color, true, false)
			"parked":
				var col: Color = CAR_COLORS[int(Iso.hash01(int(it.p.x * 10), int(it.p.y * 10)) * 7.99)]
				_vehicle(it.p, Vector2(0, 1), 0.75, 0.36, 6.0, col.darkened(0.2), false, false)
			"parked_amb":
				_vehicle(it.p, Vector2(0, 1), 0.9, 0.42, 9.0, Color("bdb8a8"), false, true, false)
			"amb":
				_vehicle(it.p, it.dir, 0.95, 0.42, 9.0, Color("d8d2c0"), true, true, true)
			"ped":
				_ped(it.p, it.c)
			"staff":
				_staff(it.s, it.p)


func _route_pos(route: Array, k: float) -> Dictionary:
	var total := 0.0
	for i in range(1, route.size()):
		total += route[i - 1].distance_to(route[i])
	var d := k * total
	for i in range(1, route.size()):
		var seg: float = route[i - 1].distance_to(route[i])
		if d <= seg or i == route.size() - 1:
			var dir: Vector2 = (route[i] - route[i - 1]).normalized()
			return {"pos": route[i - 1].lerp(route[i], clampf(d / maxf(seg, 0.001), 0.0, 1.0)), "dir": dir}
		d -= seg
	return {"pos": route[route.size() - 1], "dir": Vector2(1, 0)}


func _vehicle(c: Vector2, dir: Vector2, length: float, width: float, h: float, col: Color, lit: bool, ambulance: bool, beacon := false) -> void:
	var along_x := absf(dir.x) > absf(dir.y)
	var hx := length * 0.5 if along_x else width * 0.5
	var hy := width * 0.5 if along_x else length * 0.5
	var x0 := c.x - hx
	var x1 := c.x + hx
	var y0 := c.y - hy
	var y1 := c.y + hy
	var left := col.darkened(0.15)
	var right := col.darkened(0.45)
	# Shadow
	draw_colored_polygon(Iso.quad(x0 - 0.05, y0 - 0.05, hx * 2 + 0.15, hy * 2 + 0.15), Color(0, 0, 0, 0.35))
	draw_colored_polygon(PackedVector2Array([Iso.pxy(x0, y1, 1), Iso.pxy(x1, y1, 1), Iso.pxy(x1, y1, h), Iso.pxy(x0, y1, h)]), left)
	draw_colored_polygon(PackedVector2Array([Iso.pxy(x1, y1, 1), Iso.pxy(x1, y0, 1), Iso.pxy(x1, y0, h), Iso.pxy(x1, y1, h)]), right)
	draw_colored_polygon(Iso.quad(x0, y0, hx * 2, hy * 2, h), col.lightened(0.05))
	if not ambulance and h < 8.0:
		# Cabin
		var cx0 := x0 + (hx * 0.5 if along_x else 0.0)
		var cy0 := y0 + (0.0 if along_x else hy * 0.5)
		var cw := hx if along_x else hx * 2
		var cd := hy * 2 if along_x else hy
		draw_colored_polygon(Iso.quad(cx0, cy0, cw, cd, h + 3.5), col.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([Iso.pxy(cx0, cy0 + cd, h), Iso.pxy(cx0 + cw, cy0 + cd, h), Iso.pxy(cx0 + cw, cy0 + cd, h + 3.5), Iso.pxy(cx0, cy0 + cd, h + 3.5)]), Color(0.15, 0.2, 0.26, 0.9))
	if ambulance:
		var stripe := Color(0.75, 0.15, 0.13, 0.95)
		draw_colored_polygon(PackedVector2Array([Iso.pxy(x0, y1, 4), Iso.pxy(x1, y1, 4), Iso.pxy(x1, y1, 5.5), Iso.pxy(x0, y1, 5.5)]), stripe)
		draw_colored_polygon(PackedVector2Array([Iso.pxy(x1, y1, 4), Iso.pxy(x1, y0, 4), Iso.pxy(x1, y0, 5.5), Iso.pxy(x1, y1, 5.5)]), stripe.darkened(0.3))
		var top := Iso.p(c, h + 2)
		if beacon:
			var phase := fmod(_time * 3.0, 1.0)
			var bc := Color(0.35, 0.55, 1.0) if phase < 0.5 else Color(1.0, 0.25, 0.2)
			draw_circle(top, 2.2, bc)
			lights.append([Iso.p(c), 56.0, Color(bc.r, bc.g, bc.b, 0.4), true])
		else:
			draw_circle(top, 1.6, Color(0.3, 0.4, 0.6))
	if lit:
		var front := c + dir * (length * 0.5)
		var back := c - dir * (length * 0.5)
		var side := Vector2(-dir.y, dir.x) * width * 0.3
		draw_circle(Iso.p(front + side, 3), 1.3, Color(1, 0.95, 0.8))
		draw_circle(Iso.p(front - side, 3), 1.3, Color(1, 0.95, 0.8))
		draw_circle(Iso.p(back + side, 3), 1.1, Color(1, 0.2, 0.15))
		draw_circle(Iso.p(back - side, 3), 1.1, Color(1, 0.2, 0.15))
		lights.append([Iso.p(front + dir * 0.9), 26.0, Color(1.0, 0.9, 0.7, 0.22), true])


func _ped(p: Vector2, d: Dictionary) -> void:
	var s := Iso.p(p)
	var bob := sin(_time * 8.0 + p.x * 3.0) * 0.5
	draw_line(s, s - Vector2(0, 6 + bob), d.coat, 2.2)
	draw_circle(s - Vector2(0, 7.5 + bob), 1.4, Color(0.55, 0.5, 0.45))
	if d.umbrella:
		draw_arc(s - Vector2(0, 9.5 + bob), 4.0, PI, TAU, 8, Color(0.08, 0.09, 0.11), 2.0)


func _staff(s: StaffMember, p: Vector2) -> void:
	var w := Iso.p(p)
	var moving := s.state == StaffMember.State.MOVING
	var bob := sin(_time * 10.0) * 0.8 if moving else 0.0
	var selected := Game.selected_staff_id == s.id or Game.dragging_staff_id == s.id
	var ring := s.data.accent
	ring.a = 0.85 if selected else 0.4
	if selected:
		var pulse := 1.0 + 0.15 * sin(_time * 6.0)
		draw_arc(w, 7.0 * pulse, 0, TAU, 20, Color(1, 1, 1, 0.9), 1.5)
	_ellipse(w, 5.5, ring, 1.2)
	var body: Color = CATEGORY_COLORS.get(s.data.category, Color.WHITE)
	if s.is_locked():
		body = body.darkened(0.5)
	draw_line(w - Vector2(1.5, 0), w - Vector2(1.5, 5 + bob), Color("1b1f25"), 1.6)
	draw_line(w + Vector2(1.5, 0), w + Vector2(1.5, 5 - bob), Color("1b1f25"), 1.6)
	draw_colored_polygon(PackedVector2Array([w + Vector2(-3.5, -4), w + Vector2(3.5, -4), w + Vector2(3, -12 + bob), w + Vector2(-3, -12 + bob)]), body)
	draw_circle(w - Vector2(0, 14.5 - bob), 2.6, Color(0.82, 0.68, 0.58))
	if s.data.category == "security":
		draw_line(w - Vector2(3, 16.5 - bob), w - Vector2(-3, 16.5 - bob), Color("1a2230"), 2.0)
	lights.append([w, 14.0, Color(s.data.accent.r, s.data.accent.g, s.data.accent.b, 0.18 if selected else 0.08)])


func _ellipse(c: Vector2, r: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, col, width, true)


## Staff token hit test in world coords.
func staff_at(world: Vector2) -> String:
	var best := ""
	var best_d := 12.0
	for s: StaffMember in Game.staff.values():
		var w := Iso.p(s.position_at(Game.minutes)) - Vector2(0, 8)
		var d := w.distance_to(world)
		if d < best_d:
			best_d = d
			best = s.id
	return best
