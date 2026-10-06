class_name Iso
extends RefCounted
## 2:1 isometric projection helpers. Tile coords (x, y) -> world pixels.

const TW := 64.0
const TH := 32.0
const FLOOR := 11.0


static func p(t: Vector2, z: float = 0.0) -> Vector2:
	return Vector2((t.x - t.y) * TW * 0.5, (t.x + t.y) * TH * 0.5 - z)


static func pxy(x: float, y: float, z: float = 0.0) -> Vector2:
	return Vector2((x - y) * TW * 0.5, (x + y) * TH * 0.5 - z)


static func to_tile(w: Vector2) -> Vector2:
	var a := w.x / (TW * 0.5)
	var b := w.y / (TH * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## Diamond for an axis-aligned tile rect at height z.
static func quad(x: float, y: float, w: float, d: float, z: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([pxy(x, y, z), pxy(x + w, y, z), pxy(x + w, y + d, z), pxy(x, y + d, z)])


static func hash01(a: int, b: int = 0, c: int = 0) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0
