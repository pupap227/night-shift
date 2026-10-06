class_name CityModel
extends RefCounted
## Parsed, render-ready city description (from data/city_map.json).

const GROUND := {
	"grass": Color("0d1513"), "field": Color("0a100f"), "yard": Color("1c222a"),
	"asphalt": Color("171c23"), "parking": Color("1a1f26"), "industrial": Color("121516"),
}

var size := Vector2i(44, 44)
var ground: PackedStringArray = []         # per tile zone id
var road_tiles: Dictionary = {}            # Vector2i -> kind
var roads: Array = []                      # [{rect: Rect2, kind, name}]
var buildings: Array = []                  # dicts, sorted back-to-front
var building_by_id: Dictionary = {}
var trees: Array[Vector3] = []             # x, y, size
var lamps: Array[Vector2] = []
var lanes: Array = []
var walkways: Array = []
var routes: Dictionary = {}
var pois: Array = []
var ambulance_bay := Vector2(11.6, 20.5)
var parked_ambulances: Array[Vector2] = []
var parked_cars: Array[Vector2] = []
var camera_start := Vector2(18, 17)
var camera_zoom := 1.0


func load_from(d: Dictionary) -> void:
	var s: Array = d.get("size", [44, 44])
	size = Vector2i(s[0], s[1])
	ground.resize(size.x * size.y)
	for z in d.get("zones", []):
		var r: Array = z.rect
		for y in range(r[1], r[1] + r[3]):
			for x in range(r[0], r[0] + r[2]):
				if x >= 0 and y >= 0 and x < size.x and y < size.y:
					ground[y * size.x + x] = z.ground
	for rd in d.get("roads", []):
		var r: Array = rd.rect
		roads.append({"rect": Rect2(r[0], r[1], r[2], r[3]), "kind": rd.kind, "name": rd.get("name", "")})
		for y in range(r[1], r[1] + r[3]):
			for x in range(r[0], r[0] + r[2]):
				road_tiles[Vector2i(x, y)] = rd.kind
	for b in d.get("buildings", []):
		var r: Array = b.rect
		var bb := {
			"id": b.id, "rect": Rect2(r[0], r[1], r[2], r[3]), "floors": int(b.floors),
			"style": b.get("style", "panel"), "roof": b.get("roof", "flat"), "lit": float(b.get("lit", 0.3)),
			"accent": Color(b.get("accent", "#000000")), "has_accent": b.has("accent"), "sign": b.get("sign", ""),
			"seed": hash(b.id) & 0xFFFF,
		}
		bb.h = float(bb.floors) * Iso.FLOOR + (4.0 if bb.style in ["industrial"] else 0.0)
		if bb.style == "chimney":
			bb.h = float(bb.floors) * Iso.FLOOR
		if b.has("height"):
			bb.h = float(b.height)
		bb.depth = r[0] + r[2] + r[1] + r[3]
		bb.silhouette = _silhouette(bb.rect, bb.h)
		buildings.append(bb)
		building_by_id[b.id] = bb
	buildings.sort_custom(func(a, b): return a.depth < b.depth or (a.depth == b.depth and a.rect.position.x < b.rect.position.x))
	_place_trees(d)
	_place_lamps(d.get("lamp_spacing", 5))
	lanes = d.get("lanes", [])
	walkways = d.get("walkways", [])
	for k in d.get("routes", {}):
		var pts: Array[Vector2] = []
		for q in d.routes[k]:
			pts.append(Vector2(q[0], q[1]))
		routes[k] = pts
	pois = d.get("pois", [])
	var bay: Array = d.get("ambulance_bay", [11.6, 20.5])
	ambulance_bay = Vector2(bay[0], bay[1])
	for q in d.get("parked_ambulances", []):
		parked_ambulances.append(Vector2(q[0], q[1]))
	for q in d.get("parked_cars", []):
		parked_cars.append(Vector2(q[0], q[1]))
	var cs: Array = d.get("camera_start", [18, 17])
	camera_start = Vector2(cs[0], cs[1])
	camera_zoom = float(d.get("camera_zoom", 1.0))


func zone_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		return ""
	return ground[y * size.x + x]


func is_road(x: int, y: int) -> bool:
	return road_tiles.has(Vector2i(x, y))


func is_built(x: float, y: float) -> bool:
	for b in buildings:
		if b.rect.grow(0.25).has_point(Vector2(x, y)):
			return true
	return false


func world_bounds() -> Rect2:
	var a := Iso.pxy(0, size.y)
	var b := Iso.pxy(size.x, 0)
	var c := Iso.pxy(0, 0)
	var e := Iso.pxy(size.x, size.y)
	return Rect2(a.x, c.y - 220.0, b.x - a.x, e.y - c.y + 220.0)


static func _silhouette(r: Rect2, h: float) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([
		Iso.pxy(x0, y0, h), Iso.pxy(x1, y0, h), Iso.pxy(x1, y0, 0), Iso.pxy(x1, y1, 0),
		Iso.pxy(x0, y1, 0), Iso.pxy(x0, y1, h)])


func _place_trees(d: Dictionary) -> void:
	var cfg: Dictionary = d.get("trees", {})
	var zones: Array = cfg.get("zones", ["grass"])
	var dens: float = cfg.get("density", 0.1)
	var seed_v: int = cfg.get("seed", 1)
	for y in size.y:
		for x in size.x:
			if not zones.has(zone_at(x, y)) or is_road(x, y):
				continue
			if _near_road(x, y):
				continue
			var hsh := Iso.hash01(x, y, seed_v)
			if hsh > dens:
				continue
			var tx := x + 0.2 + Iso.hash01(x, y, seed_v + 1) * 0.6
			var ty := y + 0.2 + Iso.hash01(x, y, seed_v + 2) * 0.6
			if is_built(tx, ty):
				continue
			trees.append(Vector3(tx, ty, 0.8 + Iso.hash01(x, y, seed_v + 3) * 0.5))
	for q in d.get("fixed_trees", []):
		trees.append(Vector3(q[0], q[1], 0.9 + Iso.hash01(int(q[0] * 10), int(q[1] * 10)) * 0.3))


func _near_road(x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if is_road(x + dx, y + dy):
				return true
	return false


func _place_lamps(spacing: int) -> void:
	for rd in roads:
		var r: Rect2 = rd.rect
		if rd.kind == "drive":
			continue
		var vertical := r.size.y > r.size.x
		if vertical:
			var x := r.position.x - 0.15
			var y := r.position.y + 2.0
			while y < r.end.y:
				if not _lamp_blocked(x, y):
					lamps.append(Vector2(x, y))
				y += spacing
		else:
			var y2 := r.end.y + 0.15
			var x2 := r.position.x + 1.0
			while x2 < r.end.x:
				if not _lamp_blocked(x2, y2):
					lamps.append(Vector2(x2, y2))
				x2 += spacing


func _lamp_blocked(x: float, y: float) -> bool:
	return is_road(int(floor(x)), int(floor(y)))
