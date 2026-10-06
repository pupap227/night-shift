class_name CityMarkers
extends Node2D
## Gameplay overlays on the map: event pins, ambulance routes, staff walking paths,
## department rings (hover / selection / drop target).

var model: CityModel
var actors: CityActors
var map: Node
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if model == null:
		return
	# Department rings: verdicts while targeting, red pulse where people are needed.
	for d: DepartmentData in Game.db.departments.values():
		var c := Iso.p(d.entrance)
		var col := Color(0, 0, 0, 0)
		var big := false
		if map and map.verdicts.has(d.id):
			col = map.verdicts[d.id].color
			big = map.drag_hover_dept == d.id
		else:
			for pc in Game.cases_in(d.id):
				if pc.status == PatientCase.Status.WAITING and not pc.open_slots().is_empty():
					col = Color(0.9, 0.22, 0.2, 0.55 + 0.35 * sin(_time * 4.0))
		if col.a <= 0.0:
			continue
		var pulse := 1.0 + 0.1 * sin(_time * 5.0)
		var r := (40.0 if big else 28.0) * pulse
		var fill := col
		fill.a *= 0.18 if not big else 0.3
		draw_colored_polygon(_ellipse_pts(c, r), fill)
		_ellipse(c, r, col, 2.5 if big else 1.8)
	# Staff walking paths.
	for s: StaffMember in Game.staff.values():
		if s.state != StaffMember.State.MOVING or s.path.size() < 2:
			continue
		var col := s.data.accent
		col.a = 0.55
		var cur := s.position_at(Game.minutes)
		var pts := PackedVector2Array([Iso.p(cur)])
		# Remaining path only.
		var total := 0.0
		for i in range(1, s.path.size()):
			total += s.path[i - 1].distance_to(s.path[i])
		var k := clampf(inverse_lerp(s.move_start, s.move_end, Game.minutes), 0.0, 1.0) * total
		var acc := 0.0
		for i in range(1, s.path.size()):
			acc += s.path[i - 1].distance_to(s.path[i])
			if acc > k:
				pts.append(Iso.p(s.path[i]))
		if pts.size() >= 2:
			_dashed_poly(pts, col)
		var end := Iso.p(s.path[s.path.size() - 1])
		_ellipse(end, 6.0, col, 1.2)
	# Inbound ambulances: route ahead.
	for uid in actors.ambulances:
		var a: Dictionary = actors.ambulances[uid]
		if Game.minutes >= a.end:
			continue
		var route: Array = a.route
		var pts2 := PackedVector2Array()
		for q in route:
			pts2.append(Iso.p(q))
		_dashed_poly(pts2, Color(0.9, 0.3, 0.25, 0.4))
	# Event pins at city incident locations (pending decision or ambulance still en route).
	for ev in Game.events:
		var tile := ev.data.city_tile
		if tile.x < 0:
			continue
		var live := not ev.resolved
		for uid in ev.case_uids:
			var c := Game.get_case(uid)
			if c and c.status == PatientCase.Status.INBOUND:
				live = true
		if not live and Game.minutes - ev.arrived_at > 25.0:
			continue
		_pin(Iso.p(tile), ev, live)


func _pin(w: Vector2, ev: EventInstance, live: bool) -> void:
	var col := Color(0.86, 0.24, 0.22) if ev.data.urgent else Color(0.85, 0.65, 0.3)
	if not live:
		col = Color(0.5, 0.55, 0.6)
	var t := fmod(_time * 0.8, 1.0)
	if live:
		var c1 := col
		c1.a = 0.8 * (1.0 - t)
		_ellipse(w, 10.0 + t * 46.0, c1, 2.0)
	var c2 := col
	c2.a = 0.35
	draw_colored_polygon(_ellipse_pts(w, 10.0), c2)
	draw_line(w, w - Vector2(0, 34), col, 1.5)
	var head := w - Vector2(0, 44)
	draw_circle(head, 11.0, Color(0.06, 0.07, 0.09, 0.95))
	draw_arc(head, 11.0, 0, TAU, 24, col, 1.5, true)
	var ic := Assets.icon(ev.data.icon)
	if ic:
		draw_texture_rect(ic, Rect2(head - Vector2(7, 7), Vector2(14, 14)), false, col.lightened(0.3))


func _ellipse_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	return pts


func _ellipse(c: Vector2, r: float, col: Color, width: float) -> void:
	var pts := _ellipse_pts(c, r)
	pts.append(pts[0])
	draw_polyline(pts, col, width, true)


func _dashed_poly(pts: PackedVector2Array, col: Color) -> void:
	var offset := fmod(_time * 20.0, 10.0)
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var len := a.distance_to(b)
		if len < 0.5:
			continue
		var dir := (b - a) / len
		var t := -offset
		while t < len:
			var t0 := maxf(0.0, t)
			var t1 := minf(len, t + 5.0)
			if t1 > t0:
				draw_line(a + dir * t0, a + dir * t1, col, 1.5)
			t += 10.0
