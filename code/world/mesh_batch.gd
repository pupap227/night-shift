class_name MeshBatch
extends RefCounted
## Collects 2D shapes into ONE vertex-coloured mesh so a whole layer (ground, every building,
## all traffic) costs a single draw call instead of thousands. Drop-in replacements for the
## CanvasItem draw_* calls the city layers use; text/textures are deferred until after the mesh
## so painter's order is kept.

var v := PackedVector2Array()
var c := PackedColorArray()
var _deferred: Array = []      # [Callable] run after the mesh is drawn
var _mesh := ArrayMesh.new()


func clear() -> void:
	v.clear()
	c.clear()
	_deferred.clear()


func colored_polygon(pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n < 3 or col.a <= 0.0:
		return
	for i in range(1, n - 1):
		v.append(pts[0]); v.append(pts[i]); v.append(pts[i + 1])
		c.append(col); c.append(col); c.append(col)


func polygon(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	var n := pts.size()
	if n < 3:
		return
	if cols.size() < n:
		colored_polygon(pts, cols[0])
		return
	for i in range(1, n - 1):
		v.append(pts[0]); v.append(pts[i]); v.append(pts[i + 1])
		c.append(cols[0]); c.append(cols[i]); c.append(cols[i + 1])


func line(a: Vector2, b: Vector2, col: Color, width: float = 1.0, _aa := false) -> void:
	var d := b - a
	if d.length_squared() < 0.0001 or col.a <= 0.0:
		return
	var nrm := Vector2(-d.y, d.x).normalized() * maxf(width, 0.8) * 0.5
	colored_polygon(PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm]), col)


func polyline(pts: PackedVector2Array, col: Color, width: float = 1.0, _aa := false) -> void:
	for i in range(1, pts.size()):
		line(pts[i - 1], pts[i], col, width)


func circle(center: Vector2, r: float, col: Color, _filled := true, _w := -1.0, _aa := false) -> void:
	var seg := 10 if r < 4.0 else 16
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	colored_polygon(pts, col)


func arc(center: Vector2, r: float, a0: float, a1: float, n: int, col: Color, width: float = 1.0, _aa := false) -> void:
	var prev := center + Vector2(cos(a0), sin(a0)) * r
	for i in range(1, n + 1):
		var a := lerpf(a0, a1, float(i) / n)
		var p := center + Vector2(cos(a), sin(a)) * r
		line(prev, p, col, width)
		prev = p


func rect(r: Rect2, col: Color, filled := true, width := 1.0) -> void:
	if filled:
		colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col)
	else:
		polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), col, width)


## Anything that is not a flat shape (text, textures) — runs after the mesh, in order.
func defer(f: Callable) -> void:
	_deferred.append(f)


func commit(ci: CanvasItem) -> void:
	if v.size() >= 3:
		_mesh.clear_surfaces()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_COLOR] = c
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		ci.draw_mesh(_mesh, null)
	for f in _deferred:
		f.call()
