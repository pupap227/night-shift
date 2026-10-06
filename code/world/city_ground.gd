class_name CityGround
extends Node2D
## Static ground layer: zones, roads, sidewalks, markings, wet puddles. Drawn once.

var model: CityModel


var B := MeshBatch.new()


func _draw() -> void:
	if model == null:
		return
	B.clear()
	_draw_tiles()
	_draw_sidewalks()
	_draw_roads()
	_draw_hospital_details()
	_draw_puddles()
	B.commit(self)


func _draw_tiles() -> void:
	# Outskirts beyond the playable grid so the camera never sees a void.
	var pad := 14
	B.colored_polygon(Iso.quad(-pad, -pad, model.size.x + pad * 2, model.size.y + pad * 2), Color("070b0d"))
	for y in range(-pad, model.size.y + pad):
		for x in range(-pad, model.size.x + pad):
			if x >= 0 and y >= 0 and x < model.size.x and y < model.size.y:
				continue
			if Iso.hash01(x, y, 3) < 0.13:
				_outskirt_tree(Vector2(x + 0.5, y + 0.5))
	for y in model.size.y:
		for x in model.size.x:
			var z := model.zone_at(x, y)
			var c: Color = CityModel.GROUND.get(z, CityModel.GROUND.grass)
			var n := Iso.hash01(x, y, 11) - 0.5
			c = c.lightened(n * 0.06) if n > 0 else c.darkened(-n * 0.08)
			B.colored_polygon(Iso.quad(x, y, 1, 1), c)
	# Yard edge (hospital fence) — thin light line.
	var fence := Iso.quad(10.05, 8.05, 17.9, 17.9)
	fence.append(fence[0])
	B.polyline(fence, Color(0.45, 0.5, 0.56, 0.35), 1.2)


func _outskirt_tree(t: Vector2) -> void:
	var p := Iso.p(t)
	B.colored_polygon(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(8, 0), p + Vector2(0, -22)]), Color("0b1313"))


func _draw_sidewalks() -> void:
	var sw := Color("2a3039")
	for rd in model.roads:
		var r: Rect2 = rd.rect
		if rd.kind == "drive":
			continue
		var w := 0.32
		if r.size.y > r.size.x:
			B.colored_polygon(Iso.quad(r.position.x - w, r.position.y, w, r.size.y), sw)
			B.colored_polygon(Iso.quad(r.end.x, r.position.y, w, r.size.y), sw)
		else:
			B.colored_polygon(Iso.quad(r.position.x, r.position.y - w, r.size.x, w), sw)
			B.colored_polygon(Iso.quad(r.position.x, r.end.y, r.size.x, w), sw)


func _draw_roads() -> void:
	for rd in model.roads:
		var r: Rect2 = rd.rect
		var col := Color("151a21") if rd.kind != "highway" else Color("13171d")
		B.colored_polygon(Iso.quad(r.position.x, r.position.y, r.size.x, r.size.y), col)
	var mark := Color(0.78, 0.78, 0.72, 0.22)
	for rd in model.roads:
		var r: Rect2 = rd.rect
		var vertical := r.size.y > r.size.x
		if rd.kind == "drive":
			continue
		if rd.kind == "highway":
			# Lane dashes + amber centre line.
			for k in [1.0, 2.0]:
				_dashed(Vector2(r.position.x, r.position.y + k), Vector2(r.end.x, r.position.y + k), mark, 0.7, 0.6)
			B.line(Iso.pxy(r.position.x, r.position.y + 0.04), Iso.pxy(r.end.x, r.position.y + 0.04), Color(0.8, 0.6, 0.25, 0.25), 1.0)
			continue
		if vertical:
			var cx := r.position.x + r.size.x * 0.5
			_dashed(Vector2(cx, r.position.y), Vector2(cx, r.end.y), mark, 0.5, 0.7)
		else:
			var cy := r.position.y + r.size.y * 0.5
			_dashed(Vector2(r.position.x, cy), Vector2(r.end.x, cy), mark, 0.5, 0.7)
	# Crosswalks where roads intersect.
	for a in model.roads:
		for b in model.roads:
			if a == b or a.kind == "drive" or b.kind == "drive":
				continue
			var ra: Rect2 = a.rect
			var rb: Rect2 = b.rect
			if ra.size.y > ra.size.x and rb.size.x > rb.size.y and ra.intersects(rb):
				var i := ra.intersection(rb)
				_zebra(i)


func _dashed(a: Vector2, b: Vector2, col: Color, dash: float, gap: float) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var t := 0.0
	while t < len:
		var t2 := minf(t + dash, len)
		var p := a + dir * t
		var q := a + dir * t2
		if not _in_crossing(p) and not _in_crossing(q):
			B.line(Iso.p(p), Iso.p(q), col, 1.0)
		t += dash + gap


func _in_crossing(t: Vector2) -> bool:
	var n := 0
	for rd in model.roads:
		if rd.kind != "drive" and rd.rect.has_point(t):
			n += 1
	return n > 1


func _zebra(i: Rect2) -> void:
	var col := Color(0.8, 0.82, 0.8, 0.13)
	for k in 5:
		var f := 0.15 + k * 0.17
		B.colored_polygon(Iso.quad(i.position.x - 0.55, i.position.y + f * i.size.y, 0.4, 0.08 * i.size.y), col)
		B.colored_polygon(Iso.quad(i.end.x + 0.15, i.position.y + f * i.size.y, 0.4, 0.08 * i.size.y), col)


func _draw_hospital_details() -> void:
	# Parking bays.
	var line := Color(0.75, 0.75, 0.7, 0.18)
	for k in 6:
		var x := 18.0 + k * 0.8
		B.line(Iso.pxy(x, 22.1), Iso.pxy(x, 23.0), line, 1.0)
		B.line(Iso.pxy(x, 23.1), Iso.pxy(x, 24.0), line, 1.0)
	# Ambulance bay: painted box + red hatch.
	var bay := Iso.quad(10.4, 19.9, 2.0, 1.1)
	bay.append(bay[0])
	B.polyline(bay, Color(0.85, 0.25, 0.22, 0.4), 1.2)
	for k in 6:
		var x := 10.6 + k * 0.3
		B.line(Iso.pxy(x, 20.0), Iso.pxy(x + 0.25, 20.9), Color(0.85, 0.25, 0.22, 0.14), 1.0)
	# Internal yard walkways (lighter asphalt).
	var walk := Color("20262f")
	B.colored_polygon(Iso.quad(10.6, 14.2, 15.8, 1.2), walk)
	B.colored_polygon(Iso.quad(10.6, 19.6, 15.8, 1.6), walk)
	B.colored_polygon(Iso.quad(16.3, 14.2, 1.4, 10.6), walk)
	B.colored_polygon(Iso.quad(10.6, 24.2, 15.8, 0.75), walk)
	# Helipad marking on the ground in front of ICU would be wrong — helipad lives on the roof.
	# Gas station forecourt lines.
	B.colored_polygon(Iso.quad(11.0, 39.0, 6.0, 0.3), Color("252b33"))


func _draw_puddles() -> void:
	for k in 140:
		var x := Iso.hash01(k, 1, 5) * model.size.x
		var y := Iso.hash01(k, 2, 5) * model.size.y
		var zone := model.zone_at(int(x), int(y))
		var on_road := model.is_road(int(x), int(y))
		if not on_road and zone != "yard" and zone != "asphalt" and zone != "parking":
			continue
		if model.is_built(x, y):
			continue
		var c := Iso.p(Vector2(x, y))
		var r := 4.0 + Iso.hash01(k, 3, 5) * 9.0
		var pts := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			var wob := 1.0 + (Iso.hash01(k, i, 9) - 0.5) * 0.35
			pts.append(c + Vector2(cos(a) * r * wob, sin(a) * r * 0.5 * wob))
		B.colored_polygon(pts, Color(0.32, 0.4, 0.5, 0.07))
		B.line(c + Vector2(-r * 0.5, -1), c + Vector2(r * 0.3, -1), Color(0.6, 0.7, 0.8, 0.07), 1.0)
