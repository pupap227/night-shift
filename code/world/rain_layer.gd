class_name RainLayer
extends Control
## Screen-space rain streaks + occasional splashes. Deliberately thin and low-contrast.

const DROPS := 260

var _drops: Array = []
var _splashes: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	for i in DROPS:
		_drops.append(_new_drop(true))


func _new_drop(anywhere: bool) -> Dictionary:
	var sz := size if size.x > 10 else Vector2(1920, 800)
	return {
		"p": Vector2(_rng.randf() * (sz.x + 200) - 100, _rng.randf() * sz.y if anywhere else -20.0),
		"v": _rng.randf_range(700, 1050), "len": _rng.randf_range(9, 20), "a": _rng.randf_range(0.05, 0.16),
	}


func _process(delta: float) -> void:
	var dir := Vector2(-0.22, 1.0).normalized()
	for d in _drops:
		d.p += dir * d.v * delta
		if d.p.y > size.y:
			if _rng.randf() < 0.25:
				_splashes.append({"p": Vector2(d.p.x, _rng.randf() * size.y), "t": 0.0})
			var n := _new_drop(false)
			d.p = n.p
			d.v = n.v
	for s in _splashes:
		s.t += delta
	_splashes = _splashes.filter(func(s): return s.t < 0.35)
	queue_redraw()


func _draw() -> void:
	var dir := Vector2(-0.22, 1.0).normalized()
	for d in _drops:
		draw_line(d.p, d.p - dir * d.len, Color(0.7, 0.78, 0.9, d.a), 1.0)
	for s in _splashes:
		var k: float = s.t / 0.35
		var r: float = 2.0 + k * 6.0
		draw_arc(s.p, r, PI, TAU, 8, Color(0.7, 0.8, 0.9, 0.12 * (1.0 - k)), 1.0)
